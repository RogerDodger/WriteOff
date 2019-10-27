package WriteOff::Controller::Guess;
use Moose;
use namespace::autoclean;
use Scalar::Util qw/looks_like_number/;
use WriteOff::Util qw/sorted/;
use WriteOff::Mode qw/:all/;

BEGIN { extends 'Catalyst::Controller'; }

sub pic :PathPart('guess') :Chained('/event/pic') :Args(0) {
   my ($self, $c) = @_;
   $c->forward('guess', [ PIC ]);
}

sub fic :PathPart('guess') :Chained('/event/fic') :Args(0) {
   my ($self, $c) = @_;
   $c->forward('guess', [ FIC ]);
}

sub guess :Private {
   my ($self, $c, $mode) = @_;

   push @{ $c->stash->{title} }, $c->string($mode->name . 'Guessing');
   $c->stash->{template} = 'vote/guess.tt';

   $c->stash->{mode} = $mode;
   $c->stash->{candts} = $c->stash->{event}->entrys->mode($mode);
   return unless $c->stash->{event}->guessing && $c->stash->{event}->has($mode->name, 'vote');

   my $rounds = $c->stash->{event}->rounds->mode($mode->name);
   $c->stash->{open} = eval { $rounds->submit->ordered->first->end_leeway };
   $c->stash->{close} = eval { $rounds->vote->reversed->first->end };
   $c->stash->{opened} = sorted $c->stash->{open}, $c->stash->{now}, $c->stash->{close};

   if ($c->stash->{opened}) {
      $c->stash->{candts} = $c->stash->{candts}->search({ artist_public => 0 })->gallery;
      $c->stash->{artists} = [
         map { $_->artist }
            $c->stash->{candts}->search({}, {
               group_by => 'artist_id',
               prefetch => 'artist',
               order_by => 'artist.name',
            })
      ];

      if ($c->user) {
         $c->stash->{theory} = $c->model("DB::Theory")->find_or_create({
            event_id => $c->stash->{event}->id,
            user_id => $c->user->id,
            mode => $c->stash->{mode}->name,
         });

         $c->stash->{fillform} = {
            map { $_->entry_id => $_->artist_id } $c->stash->{theory}->guesses->all,
         };

         $c->forward('do_guess') if $c->req->method eq 'POST';
      }
   }
}

sub do_guess :Private {
   my ($self, $c) = @_;

   my @artists = @{ $c->stash->{artists} };
   for my $entry ($c->stash->{candts}->all) {
      # Users cannot vote on their own entries
      next if $entry->user_id == $c->user_id;

      my $aid = $c->req->param($entry->id);
      next unless defined $aid;

      my $guess = $c->model('DB::Guess')->find_or_new({
         entry_id  => $entry->id,
         theory_id => $c->stash->{theory}->id,
      });

      if (looks_like_number($aid) && grep { $aid == $_->id } @artists) {
         $guess->artist_id(int $aid);
         $guess->update_or_insert;
      } elsif ($guess->in_storage) {
         $guess->delete;
      }
   }

   $c->stash->{theory}->update({ artist_id => $c->user->active_artist_id });

   $c->stash->{status_msg} = 'Vote updated';
}

__PACKAGE__->meta->make_immutable;

1;
