package WriteOff::Controller::Scoreboard;
use Moose;
use Scalar::Util qw/looks_like_number/;
use namespace::autoclean;
use WriteOff::Award qw/sort_awards/;
use WriteOff::Mode qw/:all/;
use WriteOff::Util qw/maybe/;

BEGIN { extends 'Catalyst::Controller'; }

sub index :Path('/scoreboard') {
	my ($self, $c, $gid, $fid) = @_;

	my $s = $c->stash;

	$s->{modes} = \@WriteOff::Mode::ALL;
	$s->{genres} = $c->model('DB::Genre');
	$s->{formats} = $c->model('DB::Format');

	$s->{mode} = WriteOff::Mode->find($c->paramo('mode')) // FIC;
	$s->{genre} = $s->{genres}->find_maybe($c->paramo('genre')) // $s->{genres}->find(1);

	if ($s->{mode}->is(FIC)) {
		$s->{format} = $s->{formats}->find_maybe($c->paramo('format'));
	}
	else {
		$s->{format} = undef;
	}

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

	push @{ $c->stash->{title} },
		$c->string('scoreboard'),
		($s->{format} ? () : $c->string($s->{mode}->name)),
		$c->string($s->{genre}->name),
		($s->{format} ? $c->string($s->{format}->name) : ());
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
