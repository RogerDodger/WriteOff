package WriteOff::Controller::Scoreboard;
use Moose;
use Scalar::Util qw/looks_like_number/;
use namespace::autoclean;
use WriteOff::Award qw/sort_awards/;
use WriteOff::Mode qw/:all/;
use WriteOff::Util qw/maybe/;

BEGIN { extends 'Catalyst::Controller'; }

sub index :Path('/scoreboard') {
   my ($self, $c, $gid, $mname) = @_;

   $c->stash->{genres} = $c->model('DB::Genre')->promoted;
   $c->stash->{genre} =
      $c->stash->{genres}->find_maybe($gid) //
      $c->stash->{genres}->find(1);

   $c->stash->{mode} = WriteOff::Mode->find($mname) // FIC;

   $c->stash->{gUrl} = '/scoreboard/%s/' . $c->stash->{mode}->name;
   $c->stash->{mUrl} = '/scoreboard/' . $c->stash->{genre}->id_uri . '/%s';

   $c->title_push_s($c->stash->{genre}->name);

   $c->forward('view');
}

sub view :Private {
   my ($self, $c) = @_;
   my $s = $c->stash;

   $s->{modes} = \@WriteOff::Mode::ALL;

   # Keep this behaviour to allow this view still, but it's not linked anymore
   $s->{formats} = $c->model('DB::Format');
   $s->{format} =
      $s->{mode}->is(FIC)
         ? $s->{formats}->find_maybe($c->paramo('format'))
         : undef;

   my %cond;
   $cond{"genre_id"} = $s->{genre}->id;
   $cond{"format_id"} = $s->{format}->id if $s->{format};

   my $theorys = $c->model('DB::Theory')->search(
      { %cond,
         mode => $s->{mode}->name,
         award_id => { "!=" => undef },
      },
      { join => 'event' }
   );

   $c->stash->{key} =
      join ".", 'sb', map $_->id, grep defined, map $s->{$_}, qw/mode genre format/;

   # Closure wackiness so that we delay the database hit until the first
   # call. This way a cache hit makes database hit.
   $s->{awards} = {
      for => sub {
         $c->log->debug("Seeding theorys into \%sl");
         my %sl;
         for my $theory ($theorys->all) {
            $sl{$theory->artist_id} //= [];
            push @{ $sl{$theory->artist_id} }, $theory->award;
         }

         my $for = sub {
            my $artist = shift;
            sort_awards
               grep { $_->tallied }
                  @{ $artist->awards },
                  @{ $sl{$artist->id} // [] };
         };

         $s->{awards}{for} = $for;
         $for->(@_);
      }
   };

   $s->{skey} = "score_" . ($s->{format} ? "format" : "genre");

   $s->{artists} = $c->model('DB::ArtistX')->search({}, {
      bind => [$s->{mode}->fkey, $s->{genre}->id, $s->{format} && $s->{format}->id],
      order_by => { -desc => $s->{skey} },
   });

   $s->{aUrl} = $c->uri_for_action('/artist/scores', [ '%s' ], {
      mode => $s->{mode}->name,
      genre => $s->{genre}->id,
      maybe(format => $s->{format} && $s->{format}->id),
   });

   if ($s->{format}) {
      $c->title_push_s($s->{format}->name);
   }

   $c->stash->{template} = 'scoreboard/index.tt';
}

=head1 AUTHOR

Cameron Thornton E<lt>cthor@cpan.orgE<gt>

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
