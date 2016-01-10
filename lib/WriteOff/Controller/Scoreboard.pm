package WriteOff::Controller::Scoreboard;
use Moose;
use Scalar::Util qw/looks_like_number/;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller'; }

sub index :Path('/scoreboard') {
	my ( $self, $c, $gid, $fid) = @_;

	$c->stash->{awards} = $c->model('DB::Award')->search({}, { join => { entry => "event" } });
	$c->stash->{genres} = $c->model('DB::Genre');
	$c->stash->{formats} = $c->model('DB::Format');

	my $genre = $c->stash->{genre} =
		$c->stash->{genres}->find(($gid // 0) =~ /^(\d+)/ && $1)
			// $c->stash->{genres}->first;

	my $format = $c->stash->{format} =
		$c->stash->{formats}->find(($fid // 0) =~ /^(\d+)/ && $1);

	$c->stash->{cacheKey} = 'scoreboard';
	$c->stash->{gUrl} = '/scoreboard/%s';
	$c->stash->{aUrl} = '/artist/%s/scores';

	$c->stash->{awards} = $c->stash->{awards}->search({ "event.genre_id" => $genre->id });
	$c->stash->{cacheKey} .= "~" . $genre->id;
	$c->stash->{fUrl} = '/scoreboard/' . $genre->id_uri . '/%s';
	$c->stash->{aUrl} .= '?genre=' . $genre->id_uri;

	if ($format) {
		$c->stash->{awards} = $c->stash->{awards}->search({ "event.format_id" => $format->id });
		$c->stash->{cacheKey} .= "~" . $format->id;
		$c->stash->{gUrl} .= '/' . $format->id_uri;
		$c->stash->{aUrl} .= '&format=' . $format->id_uri;
	}

	$c->stash->{artists} = $c->model('DB::Scoreboard')->search({
		format_id => $format ? $format->id : undef,
		genre_id => $genre ? $genre->id : undef,
	});

	push $c->stash->{title}, join ' ', (map $_->name, grep defined, $genre, $format), 'Scoreboard';
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
