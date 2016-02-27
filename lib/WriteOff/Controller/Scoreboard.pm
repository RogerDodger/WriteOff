package WriteOff::Controller::Scoreboard;
use Moose;
use Scalar::Util qw/looks_like_number/;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller'; }

sub index :Path('/scoreboard') {
	my ( $self, $c, $gid, $fid) = @_;

	my $genre = $c->model('DB::Genre')->find(($gid // 1) =~ /^(\d+)/ && $1);
	my $format = $c->model('DB::Format')->find(($fid // 0) =~ /^(\d+)/ && $1);

	if (!$genre) {
		$c->detach('/default');
	}
	else {
		$c->stash->{scoreboard} = $c->model('DB::Scoreboard')->search({
				format_id => $format && $format->id,
				genre_id => $genre && $genre->id,
			})->first;

		push $c->stash->{title}, join ' ',
			(map $_->name, grep defined, $genre, $format),
			$c->string('scoreboard');

		$c->stash->{template} = 'scoreboard/index.tt';
	}
}

sub calculate :Private {
	my ($self, $c, $lang, $genre, $format) = @_;

	$c->stash->{genre} = $genre;
	$c->stash->{format} = $format;

	$c->stash->{awards} = $c->model('DB::Award')->search({}, { join => { entry => "event" } });
	$c->stash->{theorys} = $c->model('DB::Theory')->search(
		{ award_id => { "!=" => undef } },
		{ join => 'event' }
	);
	$c->stash->{genres} = $c->model('DB::Genre');
	$c->stash->{formats} = $c->model('DB::Format');

	$c->stash->{gUrl} = '/scoreboard/%s';
	$c->stash->{aUrl} = '/artist/%s/scores';

	$c->stash->{$_} = $c->stash->{$_}->search({ "event.genre_id" => $genre->id }) for qw/awards theorys/;
	$c->stash->{fUrl} = '/scoreboard/' . $genre->id_uri . '/%s';
	$c->stash->{aUrl} .= '?genre=' . $genre->id_uri;

	if ($format) {
		$c->stash->{$_} = $c->stash->{$_}->search({ "event.format_id" => $format->id }) for qw/awards theorys/;
		$c->stash->{gUrl} .= '/' . $format->id_uri;
		$c->stash->{aUrl} .= '&format=' . $format->id_uri;
	}

	$c->stash->{artists} = $c->model('DB::Score')->search({
		format_id => $format && $format->id,
		genre_id => $genre && $genre->id,
	});

	$c->stash->{template} = 'scoreboard/index.tt';
	$c->stash->{wrapper} = 'wrapper/none.tt';

	my %key = (
		lang => $lang,
		genre_id => $genre->id,
		format_id => $format && $format->id,
	);
	my $body = $c->view('TT')->render($c, 'scoreboard/index_.tt');

	if (my $scoreboard = $c->model('DB::Scoreboard')->search(\%key)->first) {
		$scoreboard->update({ body => $body });
	}
	else {
		$c->model('DB::Scoreboard')->create({ %key, body => $body });
	}
}

=head1 AUTHOR

Cameron Thornton E<lt>cthor@cpan.orgE<gt>

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
