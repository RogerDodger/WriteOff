package WriteOff::Controller::Event;
use Moose;

use List::Util qw/shuffle/;
use WriteOff::Award qw/:all/;
use WriteOff::DateTime;
use WriteOff::EmailTrigger qw/:all/;
use WriteOff::Mode qw/:all/;
use WriteOff::Util qw/LEEWAY uniq/;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller'; }

sub fetch :Chained('/') :PathPart('event') :CaptureArgs(1) :ActionClass('~Fetch') {}

# Debugging method
sub e :Chained('fetch') :PathPart('e') :Args(0) {
   my ($self, $c) = @_;
   $c->debug or $c->detach('/404');

   $c->stash->{trigger} = WriteOff::EmailTrigger->find($c->req->param('t') || 'subsOpen')
      or die "Bad trigger\n";

   if ($c->req->param('m') ne 'none') {
      $c->stash->{mode} = WriteOff::Mode->find($c->req->param('m') || 'fic')
         or die "Bad mode\n";
   }
   $c->forward('/event/notify_mailing_list');
}

sub permalink :Chained('fetch') :PathPart('') :Args(0) {
   my ( $self, $c ) = @_;

   $c->stash->{event}{nocollapse} = 1;
   $c->stash->{template} = 'event/view.tt';

   if ($c->stash->{event}->commenting) {
      $c->forward('/prepare_thread', [ $c->stash->{event}->posts_rs ]);
   }

   if ($c->stash->{format} eq 'json') {
      $c->stash->{json} = $c->stash->{event}->json;
      $c->forward('View::JSON');
   }
}

sub add :Local :Args(0) {
   my ( $self, $c ) = @_;

   $c->forward('/assert_admin');
   $c->forward('form');
   $c->forward('do_add') if $c->req->method eq 'POST';
}

sub do_add :Private {
   my ( $self, $c ) = @_;

   $c->stash->{event} = $c->model('DB::Event')->new_result({});
   $c->forward('do_form');
   $c->stash->{event}->insert;
   $c->stash->{event}->create_related('rounds', $_) for @{ $c->stash->{rounds} };
   $c->forward('_upsert_staff');
   $c->stash->{event}->reset_jobs;

   # $c->stash->{trigger} = $c->model('DB::EmailTrigger')->find({ name => 'eventCreated' });
   # $c->forward('/event/notify_mailing_list');

   $c->flash->{status_msg} = $c->string('eventCreated');
   $c->res->redirect($c->uri_for_action('/event/permalink', [ $c->stash->{event}->id_uri ]));
}

sub edit :Chained('fetch') :PathPart('edit') :Args(0) {
   my ($self, $c) = @_;

   $c->forward('assert_organiser');
   $c->forward('form');
   $c->stash->{rorder} = $c->stash->{event}->rorder;
   $c->stash->{dateFrozen} = $c->stash->{event}->started;
   $c->stash->{rulesFrozen} = $c->stash->{event}->fic_gallery_opened;
   $c->forward('do_edit') if $c->req->method eq 'POST';
}

sub do_edit :Private {
   my ($self, $c) = @_;

   $c->forward('do_form');

   my %keep;
   my $rounds_rs = $c->stash->{event}->rounds;
   for my $round (@{ $c->stash->{rounds} }) {
      if (exists $round->{id}) {
         my $row = $round->{row} = $rounds_rs->find_maybe($round->{id})
            or $c->yuck($c->string('badInput'));

         if ($row->finished) {
            $row->start == $round->{start} && $row->end == $round->{end}
               or $c->yuck($c->string('cantChangeFinishedRound'));
         }

         if ($row->active) {
            $row->start == $round->{start}
               or $c->yuck($c->string('cantChangeActiveRoundStart'));
         }

         if ($row->finished || $row->active) {
            $row->mode eq $round->{mode} &&
            $row->action eq $round->{action}
               or $c->yuck($c->string('badInput'));
         }

         $keep{$row->id} = 1;
      }
      else {
         $round->{start} > $c->stash->{now}
            or $c->yuck($c->string('cantMakeRoundAlreadyStarted'));
      }
   }

   for my $row ($rounds_rs->all) {
      $row->delete if !$keep{$row->id};
   }

   for my $round (@{ $c->stash->{rounds} }) {
      if (my $row = delete $round->{row}) {
         $row->update($round);
      }
      else {
         $c->stash->{event}->create_related('rounds', $round);
      }
   }

   $c->stash->{event}->update;
   $c->forward('_upsert_staff');
   $c->stash->{event}->reset_jobs;

   $c->flash->{status_msg} = $c->string('eventUpdated');
   $c->res->redirect($c->uri_for_action('/event/permalink', [ $c->stash->{event}->id_uri ]));
}

sub form :Private {
   my ($self, $c) = @_;

   $c->stash->{minDate} = $c->stash->{now}->clone->add(hours => 2);
   $c->stash->{contentLevels} = [ qw/E T A M/ ];
   $c->stash->{modes} = \@WriteOff::Mode::ALL;
   $c->stash->{formats} = $c->model('DB::Format');
   $c->stash->{genres} = $c->model('DB::Genre');
}

sub do_form :Private {
   my ($self, $c) = @_;

   $c->forward('/check_csrf_token');

   my $start = WriteOff::DateTime->parse($c->paramo('date'), $c->paramo('time'));
   my $prompt = $c->paramo('prompt');
   my $blurb = $c->paramo('blurb');
   my $genre = $c->stash->{genres}->find_maybe($c->paramo('genre'));
   my $format = $c->stash->{formats}->find_maybe($c->paramo('format'));
   my $clevel = $c->paramo('content_level');
   my $wc_min = $c->parami('wc_min');
   my $wc_max = $c->parami('wc_max');

   $c->yuck($c->string('badInput'))
      if (grep !defined, $start, $format, $genre)
      or (!grep $_ eq $clevel, @{ $c->stash->{contentLevels} })
      or $c->config->{len}{max}{prompt} < length $prompt
      or $c->config->{len}{max}{blurb} < length $blurb;

   if ($wc_min > $wc_max) {
      ($wc_min, $wc_max) = ($wc_max, $wc_min);
   }

   if ($c->stash->{dateFrozen}) {
      $start = $c->stash->{event}->start;
   }
   elsif ($start <= $c->stash->{minDate}) {
      $c->yuck($c->string('eventTooSoon'));
   }

   $c->stash->{event}->set_column(blurb => $blurb);

   if (!$c->stash->{rulesFrozen}) {
      $c->stash->{event}->set_columns({
         format_id => $format->id,
         genre_id => $genre->id,
         content_level => $clevel,
         wc_min => $wc_min,
         wc_max => $wc_max,
      });

      if ($c->stash->{event}->in_storage && $c->stash->{event}->started) {
         $c->stash->{event}->prompt($prompt);
      }
      elsif (!length $prompt) {
         $c->stash->{event}->prompt_fixed(undef);
      }
      else {
         $c->stash->{event}->prompt_fixed($prompt);
      }
   }

   $c->forward('/round/do_form');

   my %leeway;
   for my $round (@{ $c->stash->{rounds} }) {
      # Rounds after a submit round start LEEWAY minutes late, since
      # the submit rounds are LEEWAY minutes longer than actually listed
      if ($round->{action} eq 'submit') {
         $leeway{$round->{mode}}{$round->{offset} + $round->{duration}} = 1
      }
   }

   for my $round (@{ $c->stash->{rounds} }) {
      $round->{start} = $start->clone->add(days => $round->{offset});
      $round->{end} = $round->{start}->clone->add(days => $round->{duration});

      $round->{start}->add(minutes => LEEWAY)
         if $leeway{$round->{mode}}{$round->{offset}}
         # An offset submit round is dependent on another mode's submit round,
         # (fic2pic or pic2fic) so it also has a LEEWAY added
         || $round->{action} eq 'submit' && $round->{offset};

      delete $round->{offset};
      delete $round->{duration};
   }

   my %staff = (
      judge => [],
      (organiser => []) x!! $c->user->admin,
   );
   $c->stash->{staff} = \%staff;

   my $artists = $c->model('DB::Artist');
   for my $role (keys %staff) {
      my @ids = $c->req->param("${role}_id");
      for my $id (uniq @ids) {
         my $artist = $artists->find_maybe($id) or $c->yuk('badInput');
         push @{ $staff{$role} }, $artist;
      }
   }

   if (exists $staff{organiser} && !@{ $staff{organiser} }) {
      push @{ $staff{organiser} }, $c->user->active_artist;
   }
}

sub _upsert_staff :Private {
   my ($self, $c) = @_;

   for my $role (keys %{ $c->stash->{staff} }) {
      $c->stash->{event}->artist_events->search({ role => $role })->delete;
      for my $staff (@{ $c->stash->{staff}{$role} }) {
         $c->stash->{event}->create_related('artist_events', {
            artist_id => $staff->id,
            role => $role,
         });
      }
   }
}

sub fic :Chained('fetch') :PathPart('fic') :CaptureArgs(0) {
   my ( $self, $c ) = @_;

   $c->detach('/error', ['There is no fic component to this event.'])
      unless $c->stash->{event}->has('fic');

   push @{ $c->stash->{title} }, 'Fic';
}

sub pic :Chained('fetch') :PathPart('pic') :CaptureArgs(0) {
   my ( $self, $c ) = @_;

   $c->detach('/error', ['There is no pic component to this event.'])
      unless $c->stash->{event}->has('pic');

   push @{ $c->stash->{title} }, 'Pic';
}

sub prompt :Chained('fetch') :PathPart('prompt') :CaptureArgs(0) {
   my ( $self, $c ) = @_;

   $c->detach('/error', ['There is no prompt round for this event.'])
      if $c->stash->{event}->prompt_fixed;

   push @{ $c->stash->{title} }, 'Prompt';
}

sub vote :Chained('fetch') :PathPart('vote') :CaptureArgs(0) {
   my ( $self, $c ) = @_;

   $c->detach('/error', ['There is no voting component to this event.'])
      unless $c->stash->{event}->has('voting');

   push @{ $c->stash->{title} }, 'Vote';
}

sub rules :Chained('fetch') :PathPart('rules') :Args(0) {
   my ( $self, $c ) = @_;

   $c->stash->{template} = 'event/rules.tt';
   push @{ $c->stash->{title} }, 'Rules';
}

sub results :Private {
   my ( $self, $c ) = @_;

   # Copy this now since we're going to overwrite with a prefetched RS
   my $entrys_clean = $c->stash->{entrys};

   $c->stash->{theorys} = $c->stash->{event}->theorys->search({ mode => $c->stash->{mode} });

   # Lazy load this since we don't want to make DB hits if the template cache
   # comes through
   $c->stash->{graph} = sub {
      {
         theorys => [
            $c->stash->{theorys}->search({}, {
               join => [qw/artist guesses/],
               group_by => [ 'me.id' ],
               having => [ \'count(guesses.id) >= 1' ],
               order_by => [
                  { -desc => 'me.accuracy' },
                  { -asc => 'artist.name' },
               ],
               columns => [qw/me.id me.artist_id me.accuracy/],
               '+columns' => {
                  'artist_name' => 'artist.name',
               },
               result_class => 'DBIx::Class::ResultClass::HashRefInflator',
            }),
         ],
         artists => [
            map {{ id => $_->id, name => $_->name }}
               values %{ $entrys_clean->artists_hash }
         ],
         entrys => [
            $entrys_clean->search({}, {
               columns => [qw/me.id me.artist_id me.title/],
               result_class => 'DBIx::Class::ResultClass::HashRefInflator',
            })
         ],
         guesses => [
            $c->model('DB::GuessX')->search({}, {
               bind => [$c->stash->{event}->id],
               result_class => 'DBIx::Class::ResultClass::HashRefInflator',
            })
         ],
      }
   };

   $c->stash->{entrys} = $c->stash->{entrys}->search({}, {
      prefetch => [ qw/artist awards ratings/ ],
      order_by => [
         { -asc => 'rank' },
         { -asc => 'title' },
      ],
   });

   my $rounds = $c->stash->{event}->rounds->search(
      {
         mode => $c->stash->{mode},
         action => 'vote',
      },
      {
         order_by => { -desc => 'end' },
      }
   );

   $c->stash->{final} = $rounds->first;

   # Filter out rounds without ratings
   $c->stash->{rounds} = [grep { $_->ratings->count } $rounds->all];

   for my $round (@{ $c->stash->{rounds} }) {
      $round->{has_error} = $round->ratings->search({ error => { "!=" => undef }})->count;
   }

   $c->stash->{ratings} = $c->model('DB::Rating');

   push @{ $c->stash->{title} }, $c->string($c->stash->{mode} . 'Results');
   $c->stash->{template} = 'event/results.tt';
}

sub view :Chained('fetch') :PathPart('submissions') :Args(0) {
   my ( $self, $c ) = @_;

   $c->forward( $self->action_for('assert_organiser') );

   $c->detach('/default', [ 'Page under development...' ]);
}

sub assert_organiser :Private {
   my ( $self, $c, $msg ) = @_;

   $c->user->organises($c->stash->{event})
      or $c->detach('/forbidden', [ $c->string('notOrganiser') ]);
}

sub notify_mailing_list :Private {
   my ($self, $c) = @_;

   return unless $c->stash->{trigger};

   $c->log->info("[mail] sending %s for event #%d",
      $c->stash->{trigger}->name,
      $c->stash->{event}->id,
   );

   $c->stash->{email} = {
      users => $c->model('DB::User')->subscribers(
         event => $c->stash->{event},
         trigger => $c->stash->{trigger},
         mode => $c->stash->{mode},
      ),
      subject => $c->stash->{trigger}->is(EVENTCREATED)
         ? ( sprintf "[#%d] %s | %s %s",
            $c->stash->{event}->id,
            $c->string($c->stash->{trigger}->name),
            $c->string($c->stash->{event}->genre->name),
            $c->string($c->stash->{event}->format->name) )
         : ( sprintf "[#%d] %s%s | %s",
            $c->stash->{event}->id,
            ( $c->stash->{mode}
               ? $c->string($c->stash->{mode}->name) . ' '
               : '' ),
            $c->string($c->stash->{trigger}->name),
            $c->stash->{event}->prompt ),
      template => $c->stash->{trigger}->template,
   };

   $c->stash->{bulk} = 1;
   $c->forward('View::Email');
}

sub set_prompt :Private {
   my ($self, $c, $id) = @_;

   my $e = $c->stash->{event} = $c->model('DB::Event')->find($id) or return 0;

   if ($e->prompt_fixed) {
      $e->update({ prompt => $e->prompt_fixed });
   }
   else {
      # In case of tie, we take the first, which is random
      my @p = shuffle $e->prompts->all;
      my $best = $p[0];
      for my $p (@p) {
         if ($p->score > $best->score) {
            $best = $p;
         }
      }

      if ($best) {
         $e->update({ prompt => $best->contents });
      }
   }

   if ($e->rorder =~ /^(fic|pic)/) {
      $c->stash->{mode} = WriteOff::Mode->find($1);
   }

   $c->stash->{trigger} = SUBSOPEN;
   $c->forward('/event/notify_mailing_list');
}

sub subs_open :Private {
   my ($self, $c, $eid, $mode) = @_;

   $c->stash->{event} = $c->model('DB::Event')->find($eid) or return;
   $c->stash->{mode} = WriteOff::Mode->find($mode) or return;
   $c->stash->{trigger} = SUBSOPEN;

   $c->forward('/event/notify_mailing_list');
}

sub voting_started :Private {
   my ($self, $c, $eid, $mode) = @_;

   $c->stash->{event} = $c->model('DB::Event')->find($eid) or return;
   $c->stash->{mode} = WriteOff::Mode->find($mode) or return;
   $c->stash->{trigger} = VOTINGSTARTED;

   $c->forward('/event/notify_mailing_list');
}

sub tally_round :Private {
   my ( $self, $c, $eid, $rid ) = @_;

   my $e = $c->model('DB::Event')->find($eid) or return;
   my $r = $c->model('DB::Round')->find($rid) or return;

   $c->log->info("Tallying %s %s round for %s", $r->mode, $r->name, $e->prompt);
   $r->tally($c->config->{work});

   if ($r->name eq 'final') {
      $c->log->info("Tallying %s results for %s", $r->mode, $e->prompt);

      $e->theorys->search({ mode => $r->mode })->process if $e->guessing;
      $e->score($r->mode);

      $c->stash->{mode} = WriteOff::Mode->find($r->mode);
      $c->stash->{event} = $e;
      $c->stash->{trigger} = RESULTSUP;
      $c->forward('/event/notify_mailing_list');
   }

   if ($r->end == $e->end) {
      $e->update({ tallied => 1 });
   }

   $r->update({ tallied => 1 });
}

=head1 AUTHOR

Cameron Thornton E<lt>cthor@cpan.orgE<gt>

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
