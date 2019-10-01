package WriteOff::Schema::ResultSet::Event;

use strict;
use base 'WriteOff::Schema::ResultSet';
use Carp ();
use WriteOff::Util qw/LEEWAY/;

sub active {
   my $self = shift;
   $self->search(
      { tallied => 0 },
      {
         alias => 'events',
         order_by => 'events.created',
      }
   );
}

sub active_rs {
   scalar shift->active;
}

sub archive {
   my $self = shift;
   my $dt = shift // $self->now_dt;

   my $mindt = $self->format_datetime(DateTime->new(year => $dt->year));
   my $maxdt = $self->format_datetime(DateTime->new(year => $dt->year + 1));

   $self->search({}, {
      alias => 'events',
      join => 'rounds',
      group_by => 'events.id',
      '+select' => [
         { min => 'rounds.start', -as => 'start' },
      ],
      order_by => { -desc => 'start' },
      having => \[
         q{ start >= ? AND start <= ? },
         $mindt, $maxdt
      ],
   });
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
   my $genre = $sched->genre;

   my $event = $self->create({
      format_id => $sched->format->id,
      genre_id => $genre->id,
      wc_min => $sched->wc_min,
      wc_max => $sched->wc_max,
      content_level => 'T',
   });

   $event->add_to_artists($genre->owner, { role => 'organiser' });
   for my $artist (defined $orgs ? $orgs->all : ()) {
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

sub last_ended {
   my $self = shift;

   $self->search({
      'events.tallied' => 1,
   }, {
      alias => 'events',
      join => 'rounds',
      group_by => 'events.id',
      '+select' => { max => 'rounds.end', -as => 'fin' },
      order_by => { -desc => 'fin' },
      rows => 1,
   });
}

# Exclude active events and the last event, then sort by last post date
sub forum {
   my $self = shift;
   my $t = $self->format_datetime($self->now_dt->subtract(months => 2));

   $self->search(
      {
         'events.tallied' => 1,
         'events.id' => { '!=' =>
            $self->last_ended->get_column('id')->max_rs->as_query },
         'last_post.created' => { '>' => $t },
      },
      {
         alias => 'events',
         join => 'last_post',
         order_by => { -desc => 'last_post.created' },
      }
   );
}

sub forum_rs {
   scalar shift->recent;
}

sub promoted {
   shift->search({ promoted => 1 }, { join => 'genre' });
}

1;
