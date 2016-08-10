package WriteOff::Controller::Artist;
use Moose;
use namespace::autoclean;
use JSON;
use Scalar::Util qw/looks_like_number/;

BEGIN { extends 'Catalyst::Controller'; }

__PACKAGE__->config(model => 'Artist');

sub _fetch :ActionClass('~Fetch');

sub fetch :Chained('/') :PathPart('artist') :CaptureArgs(1) {
	my ($self, $c) = @_;
	$c->forward('_fetch');
	$c->stash->{entrys} = $c->stash->{artist}->entrys->listing;
	push @{ $c->stash->{title} }, $c->stash->{artist}->name;
}

sub add :Local {
	my ($self, $c) = @_;

	$c->user or $c->detach('/forbidden', [ $c->{loginRequired} ]);

	$c->forward('do_add') if $c->req->method eq 'POST';

	$c->stash->{template} = 'artist/add.tt';
	push @{ $c->stash->{title} }, $c->string('newArtistTitle');
}

sub do_add :Private {
	my ($self, $c) = @_;

	$c->forward('/check_csrf_token');

	my $name = $c->req->param('artist');
	if (1 <= length $name && length $name <= $c->config->{len}{max}{user}) {
		my $artist = $c->user->create_related('artists', { name => $name });
		$c->user->update({ active_artist => $artist });
		$c->res->redirect($c->uri_for_action('/artist/view', [ $artist->id_uri ]));
	}
}

sub edit :Chained('fetch') :PathPart('edit') :Args(0) {
	my ($self, $c) = @_;

	$c->detach('/forbidden') if $c->user->id != $c->stash->{artist}->user_id;

	if ($c->req->method eq 'POST') {
		if (defined $c->req->param('bio')) {
			$c->stash->{artist}->bio(substr $c->req->param('bio'), 0, 256);
		}

		if (defined $c->req->upload('avatar')) {
			$c->stash->{artist}->avatar_write($c->req->upload('avatar'));
		}

		$c->stash->{artist}->update;
		$c->res->redirect($c->uri_for_action('artist/view', [ $c->stash->{artist}->id_uri ]));
	}

	$c->stash->{template} = 'artist/edit.tt';
	push @{ $c->stash->{title} }, $c->string('edit');
}

sub scores :Chained('fetch') :PathPart('scores') :Args(0) {
	my ($self, $c) = @_;

	my %s = (tallied => 1);
	$s{genre_id} = $1 if ($c->req->param('genre') // '') =~ /^(\d+)/;
	$s{format_id} = $1 if ($c->req->param('format') // '') =~ /^(\d+)/;

	$c->stash->{scoreKey} = $s{format_id} ? 'score_format' : 'score_genre';

	$c->stash->{scores} = $c->stash->{artist}->entrys->search(
		{
			%s,
			disqualified => 0,
			artist_public => 1,
		},
		{
			prefetch => 'event',
			order_by => [
				{ -desc  => 'event.created' },
				{ -desc => 'score' },
			]
		}
	);

	$c->stash->{theorys} = $c->stash->{artist}->theorys->search(
		{
			%s,
			award_id => { "!=" => undef },
		},
		{
			prefetch => 'event',
			order_by => { -desc => 'event.created' },
		}
	);

	$c->stash->{title} = 'Scores';
	$c->stash->{template} = 'scoreboard/scores.tt';
}

sub swap :Local {
	my ($self, $c) = @_;

	$c->detach('/404') unless $c->req->method eq 'POST';

	$c->forward('/check_csrf_token');

	my $id = $c->req->param('artist-swap');
	return unless looks_like_number $id;

	if (my $artist = $c->user->artists->find($id)) {
		$c->user->update({ active_artist_id => $artist->id });
		if ($c->stash->{ajax}) {
			$c->res->body(encode_json {
				id => $artist->id,
				name => $artist->name,
				avatar => $artist->avatar,
			});
		}
		else {
			$c->res->redirect($c->req->referer);
		}
	}
	else {
		$c->detach('/error');
	}
}

sub view :Chained('fetch') :PathPart('') :Args(0) {
	my ($self, $c) = @_;

	$c->stash->{template} = 'artist/view.tt';
}

=head1 AUTHOR

Cameron Thornton E<lt>cthor@cpan.orgE<gt>

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
