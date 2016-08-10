package WriteOff::Controller::Scoreboard;
use Moose;
use Scalar::Util qw/looks_like_number/;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller'; }

sub index :Path('/scoreboard') {
	my ($self, $c, $gid, $fid) = @_;

	my $lang = 'en';
	my $genre = $c->stash->{genre} = $c->model('DB::Genre')->find_maybe($gid // 1);
	my $format = $c->stash->{format} = $c->model('DB::Format')->find_maybe($fid);
	my $events = $c->model('DB::Event')->search({
		tallied => 1,
		genre_id => $genre->id,
	});

	$c->detach('/default') if !$genre;

	$c->stash->{genres} = $c->model('DB::Genre');
	$c->stash->{formats} = $c->model('DB::Format');

	$c->stash->{gUrl} = '/scoreboard/%s';
	$c->stash->{fUrl} = '/scoreboard/' . $genre->id_uri . '/%s';
	$c->stash->{aUrl} = '/artist/%s/scores?genre=' . $genre->id_uri;

	if ($format) {
		$c->stash->{gUrl} .= '/' . $format->id_uri;
		$c->stash->{aUrl} .= '&format=' . $format->id_uri;
		$events = $events->search({ format_id => $format->id });
	}

	my $cache = $c->config->{scoreCache};
	my $key = join ".", $lang, $genre->id, ($format ? $format->id : ()), $events->count;
	my $rendering = "rendering.$key";

	$c->stash->{scoreboard} = $cache->get($key);
	if (!$c->stash->{scoreboard} && !$cache->get($rendering)) {
		$cache->set($rendering, 1, '10s');

		my $pid = fork;
		if (!defined $pid) {
			$c->log->error("Fork failed!: $!");
		}
		elsif (!$pid) {
			my %cond;
			$cond{"genre_id"} = $genre->id;
			$cond{"format_id"} = $format->id if $format;

			$c->stash->{awards} = $c->model('DB::Award')->search(\%cond, {
				join => { entry => "event" }
			});

			$c->stash->{theorys} = $c->model('DB::Theory')->search(
				{ award_id => { "!=" => undef }, %cond },
				{ join => 'event' }
			);

			$c->stash->{artists} = $c->model('DB::Score')->search({
				genre_id => $genre->id,
				format_id => $format ? $format->id : undef,
			});

			$c->stash->{wrapper} = 'wrapper/none.tt';
			$cache->set($key, $c->view('TT')->render($c, 'scoreboard/table.tt'), '6w');
			$cache->remove($rendering);
			exit(0);
		};
	}

	push @{ $c->stash->{title} }, join ' ', ($genre->name, $format ? $format->name : ()), $c->string('scoreboard');
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
