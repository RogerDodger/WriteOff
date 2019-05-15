package WriteOff::Schema::ResultSet::Event;

use strict;
use base 'WriteOff::Schema::ResultSet';
use Carp ();
use WriteOff::Util qw/LEEWAY/;

sub active {
   my $self = shift;
   my $t = $self->format_datetime($self->now_dt->subtract(months => 2));
   return $self->search(
      {
         -or => [
            'me.created' => { '>' => $t },
            -and => [
               'last_post_id' => { '!=' => undef },
               'last_post.created' => { '>' => $t },
            ]
         ],
      },
      {
         join => 'last_post',
         order_by => { -desc => 'me.created' },
      }
   );
}

sub archive {
   my $self = shift;
   return $self->search({},
      { order_by => { -desc => 'created' } },
   );
}

sub create_from_sched {
   my ($self, $sched, $t0, $orgs) = @_;

   Carp::croak "Schedule not defined" unless defined $sched;

   UNIVERSAL::isa($_->[0], $_->[1]) or Carp::croak "$_->[0] not a $_->[1]"
      for grep { defined $_->[0] } (
         [$sched, 'WriteOff::Schema::Result::Schedule'],
         [$t0, 'DateTime'],
         [$orgs, 'WriteOff::Schema::ResultSet::Artist'],
      );

   $t0 //= $sched->next;

   my $schema = $self->result_source->schema;
   my $format = $sched->format;
   my $genre = $sched->genre;

   my $event = $self->create({
      format_id => $format->id,
      genre_id => $genre->id,
      wc_min => $format->wc_min,
      wc_max => $format->wc_max,
      content_level => 'T',
   });

   $orgs //= $schema->resultset('Artist')->search({ admin => 1 });
   for my $artist ($orgs->all) {
      $event->add_to_artists($artist, { role => 'organiser' });
   }

   my %leeway;
   my @rounds = $sched->rounds;
   for my $round (@rounds) {
      # Rounds after a submit round start LEEWAY minutes late, since
      # the submit rounds are LEEWAY minutes longer than actually listed
      if ($round->action eq 'submit') {
         $leeway{$round->mode}{$round->offset + $round->duration} = 1;
      }
   }

   for my $round (@rounds) {
      my $start = $t0->clone->add(days => $round->offset);
      my $end = $start->clone->add(days => $round->duration);

      $start->add(minutes => LEEWAY)
         if $leeway{$round->mode}{$round->offset}
         # An offset submit round is dependent on another mode's submit round,
         # (fic2pic or pic2fic) so it also has a LEEWAY added
         || $round->action eq 'submit' && $round->offset;

      $event->create_related('rounds', {
         start => $start,
         end => $end,
         name => $round->name,
         mode => $round->mode,
         action => $round->action,
      });
   }

   $event->reset_jobs;

   $event;
}

sub finished {
   my $self = shift;
   return $self->search(
      { end => { '<' => $self->now } },
      { order_by => { -asc => 'created' } }
   );
}

1;
