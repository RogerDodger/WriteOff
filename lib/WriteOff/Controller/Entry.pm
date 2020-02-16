package WriteOff::Controller::Entry;
use Moose;
use namespace::autoclean;
use Scalar::Util qw/looks_like_number/;
use WriteOff::Mode qw/:all/;

BEGIN { extends 'Catalyst::Controller' }

sub form :Private {
   my ($self, $c) = @_;

   $c->stash->{fillform}{artist} = $c->user->active_artist_id;

   $c->stash->{rounds} = $c->stash->{event}->rounds->search({
      mode => $c->stash->{mode},
      action => 'submit',
   });

   if ($c->stash->{rounds}->active(leeway => 1)->count) {
      $c->stash->{countdown} = $c->stash->{rounds}->active(leeway => 1)->first->end;
   }
   elsif ($c->stash->{rounds}->upcoming->count) {
      $c->stash->{countdown} = $c->stash->{rounds}->upcoming->first->start;
   }

   if ($c->user) {
      my $uid = eval { $c->stash->{entry}->user_id } || $c->user->id;
      my $organiser = $c->user->organises($c->stash->{event});

      $c->stash->{artists} = $c->model('DB::Artist')->search({
         -or => [
            {
               $organiser && $c->user->id != $uid
                  ? ( id => $c->stash->{entry}->artist_id )
                  : ( user_id => $uid )
            },
            { id => 25 }, # Anonymous
         ],
      }, {
         order_by => [
            { -asc => 'created' },
         ],
      });

      if ($c->stash->{rels} && !$organiser) {
         $c->stash->{rels} = $c->stash->{rels}->search({
            user_id => { '!=' => $uid },
         });
      }
   }
}

sub do_form :Private {
   my ($self, $c) = @_;

   $c->forward('/check_csrf_token');

   # When editing, must allow for the title to be itself
   my $titles = $c->stash->{event}->storys->search({
      title => {
         '!=' => eval { $c->stash->{entry}->title } || undef
      }
   });

   $c->form(
      title => [
         [ 'LENGTH', 1, $c->config->{len}{max}{title} ],
         'TRIM_COLLAPSE',
         'NOT_BLANK',
         [ 'DBIC_UNIQUE', $titles, 'title' ],
      ],
      artist => [
         qw/NOT_BLANK INT/,
         ['NOT_DBIC_UNIQUE', $c->stash->{artists}, 'id'],
      ],
   );

   if ($c->stash->{rels}) {
      my $rkey = $c->stash->{mode} eq 'fic' ? PIC()->fkey : FIC()->fkey;

      my @ids = $c->stash->{rels}->get_column($rkey)->all;
      my @params = $c->req->param($rkey) or $c->yuck("No related works selected");

      my %uniq;
      for my $id (@params) {

         # Param must be in the set of valid @ids
         $c->yuck("Invalid $rkey: $id") unless looks_like_number($id) && grep { $id == $_ } @ids;

         # Param must be unique
         $c->yuck("Duplicate $rkey: $id") if $uniq{$id};
         $uniq{$id} = 1;
      }
   }
}

sub do_submit :Private {
   my ($self, $c) = @_;

   if (!$c->form->has_error) {
      $c->stash->{entry} = $c->model('DB::Entry')->new_result({
         user_id   => $c->user->id,
         event_id  => $c->stash->{event}->id,
         artist_id => $c->form->valid('artist'),
         title     => $c->form->valid('title'),
      });

      my $voteRounds = $c->stash->{event}->rounds->search({
         mode => $c->stash->{mode},
         action => 'vote',
      });

      if ($voteRounds->count) {
         $c->stash->{entry}->round_id($voteRounds->ordered->first->id);
      }

      $c->flash->{status_msg} = 'Submission successful';
      $c->res->redirect($c->req->uri);
   }
}

sub do_edit :Private {
   my ($self, $c) = @_;

   if (!$c->form->has_error) {
      $c->stash->{entry}->update({
         title     => $c->form->valid('title'),
         artist_id => $c->form->valid('artist'),
      });

      $c->flash->{status_msg} = 'Edit successful';
      $c->res->redirect( $c->uri_for_action(
         $c->controller->action_for('view'), [ $c->stash->{entry}->id_uri ]) );
   }
}

sub do_rels :Private {
   my ($self ,$c) = @_;

   if ($c->stash->{rels}) {
      my $ikey = FIC()->fkey;
      my $fkey = PIC()->fkey;

      if ($c->stash->{mode} eq 'pic') {
         ($ikey, $fkey) = ($fkey, $ikey);
      }

      my %q = ($ikey => $c->stash->{entry}->item_id);
      my $rs = $c->model('DB::ImageStory');
      $rs->search(\%q)->delete;
      $rs->create({ %q, $fkey => int $_ }) for $c->req->param($fkey);
   }
}

sub delete :Private {
   my ($self, $c) = @_;

   $c->detach('/forbidden', [ $c->string('cantDelete') ])
      if !$c->user->can_edit($c->stash->{entry}->item);

   $c->stash(
      key => $c->stash->{entry}->title,
      header => $c->string('confirmDeletion'),
      confirmPrompt => $c->string('confirmPrompt', $c->string('title')),
   );

   $c->forward('do_delete') if $c->req->method eq 'POST';

   push @{ $c->stash->{title} }, $c->string('delete');
   $c->stash->{template} = 'root/confirm.tt';
}

sub do_delete :Private {
   my ($self, $c) = @_;
   $c->forward('/check_csrf_token');

   $c->log->info("%s deleted by %s: %s by %s",
      ucfirst $c->stash->{entry}->mode,
      $c->user->id_uri,
      $c->stash->{entry}->title,
      $c->stash->{entry}->artist->name,
   );

   $c->stash->{entry}->item->image_stories->delete;
   $c->stash->{entry}->item->delete;
   $c->stash->{entry}->delete;

   $c->flash->{status_msg} = 'Deletion successful';
   $c->res->redirect($c->req->param('referer') || $c->uri_for('/'));
}

sub dq :Private {
   my ($self, $c) = @_;

   $c->detach('/forbidden', [ $c->string('notOrganiser') ])
      if !$c->user->organises($c->stash->{event});

   $c->stash(
      key => $c->stash->{entry}->title,
      header => $c->string('confirmDQ'),
      confirmPrompt => $c->string('confirmPrompt', $c->string('title')),
   );

   $c->forward('do_dq') if $c->req->method eq 'POST';

   push @{ $c->stash->{title} }, $c->string('dq');
   $c->stash->{template} = 'root/confirm.tt';
}

sub do_dq :Private {
   my ($self, $c) = @_;
   $c->forward('/check_csrf_token');

   $c->log->info("%s disqualified by %s: %s by %s",
      ucfirst $c->stash->{entry}->mode,
      $c->user->id_uri,
      $c->stash->{entry}->title,
      $c->stash->{entry}->artist->name,
   );

   $c->stash->{entry}->guesses->delete;

   # Only delete votes in currently active rounds
   #
   # While it's unlikely to ever occur, should the results of a previous
   # round be recalculated and this entry's votes in that round were deleted,
   # the results could change. So if the round is no longer active, its votes
   # are preserved.
   $c->stash->{entry}->votes->search(
      {
         round_id => { -in =>
            $c->stash->{entry}->event->rounds->active->get_column('id')->as_query
         }
      },
      { join => 'ballot' },
   )->delete;

   $c->stash->{entry}->update({
      artist_public => 1,
      disqualified => 1,
      round_id => undef,
   });

   $c->flash->{status_msg} = 'Entry disqualified';
   $c->res->redirect($c->req->param('referer') || $c->uri_for('/'));
}

sub votes :Private {
   my ($self, $c, $rid) = @_;

   my $round = $c->model('DB::Round')->find($rid =~ /^(\d+)/ && $1);

   if (!$round || $round->event_id != $c->stash->{event}->id || !$round->tallied) {
      $c->detach('/default');
   }

   $c->stash->{summary} = [
      sort { $b->pct <=> $a->pct || $b->right <=> $a->right || $a->left <=> $b->left }
         $c->model('DB::VoteSummary')
            ->search({}, {
               bind => [ $c->stash->{entry}->id, $round->id ]
            })
   ];

   push @{ $c->stash->{title} }, 'Vote breakdown for ' . $c->stash->{entry}->title;
   $c->stash->{template} = 'entry/votes.tt';
}

__PACKAGE__->meta->make_immutable;

1;
