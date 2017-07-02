package WriteOff::Controller::Scoreboard;
use Moose;
use Scalar::Util qw/looks_like_number/;
use namespace::autoclean;
use WriteOff::Mode qw/:all/;

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

	my $rounds = $c->model('DB::Round')->search(
		{
			'me.tallied' => 1,
			mode => $s->{mode}->name,
			name => 'final',
			genre_id => $s->{genre}->id,
		},
		{
			join => 'event',
		}
	);

	if ($s->{format}) {
		$rounds = $rounds->search({ format_id => $s->{format}->id });
	}

	my $cache = $c->config->{scoreCache};
	my $key = join ".", 'en', $s->{mode}->name, $s->{genre}->id, ($s->{format} ? $s->{format}->id : ''), $rounds->count;
	my $rendering = "rendering.$key";

	$s->{scoreboard} = $cache->get($key);
	if (!$s->{scoreboard} && !$cache->get($rendering)) {
		$cache->set($rendering, 1, '10s');

		my $pid = fork;
		if (!defined $pid) {
			$c->log->error("Fork failed!: $!");
		}
		elsif (!$pid) {
			my %cond;
			$cond{"genre_id"} = $s->{genre}->id;
			$cond{"format_id"} = $s->{format}->id if $s->{format};

			$s->{theorys} = $c->model('DB::Theory')->search(
				{ %cond,
					mode => $s->{mode}->name,
					award_id => { "!=" => undef },
				},
				{ join => 'event' }
			);

			$s->{awards} = $c->model('DB::Award')->search(
				{ %cond,
					$s->{mode}->fkey => { '!=' => undef },
				},
				{ join => { entry => "event" } }
			);

			$s->{skey} = "score_" . ($s->{format} ? "format" : "genre");

			$s->{artists} = $c->model('DB::Score')->search({}, {
				bind => [$s->{mode}->fkey, $s->{genre}->id, $s->{format} && $s->{format}->id],
				order_by => { -desc => $s->{skey} },
			});

			$s->{aUrl} = $c->uri_for_action('/artist/scores', [ '%s' ], $c->req->params);

			local $s->{wrapper} = 'wrapper/none.tt';
			$cache->set($key, $c->view('TT')->render($c, 'scoreboard/table.tt'), '6w');
			$cache->remove($rendering);
			exit(0);
		}
	}
	$c->stash->{scoreboard} = $cache->get($key);

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
