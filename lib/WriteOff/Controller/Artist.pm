package WriteOff::Controller::Artist;
use Moose;
use namespace::autoclean;
use Scalar::Util qw/looks_like_number/;

BEGIN { extends 'Catalyst::Controller'; }

__PACKAGE__->config(model => 'Artist');

sub fetch :Chained('/') :PathPart('artist') :CaptureArgs(1) :ActionClass('~Fetch') {}

sub add :Local {
	my ($self, $c) = @_;

	$c->user or $c->detach('/forbidden', [ $c->{loginRequired} ]);

	$c->forward('do_add') if $c->req->method eq 'POST';

	$c->stash->{template} = 'artist/add.tt';
	push $c->stash->{title}, $c->string('newArtistTitle');
}

sub do_add :Private {
	my ($self, $c) = @_;

	$c->forward('/check_csrf_token');

	my $name = $c->req->param('artist');
	if (1 <= length $name && length $name <= $c->config->{len}{max}{user}) {
		$c->user->update({
			active_artist => $c->user->create_related('artists', { name => $name })
		});

		$c->res->redirect($c->req->param('referer') || $c->uri_for('/'));
	}
}

sub scores :Chained('fetch') :PathPart('scores') :Args(0) {
	my ( $self, $c ) = @_;

	my %s = (tallied => 1);
	$s{genre_id} = $1 if ($c->req->param('genre') // '') =~ /^(\d+)/;
	$s{format_id} = $1 if ($c->req->param('format') // '') =~ /^(\d+)/;

	$c->stash->{scoreKey} = $s{format_id} ? 'score_format' : 'score_genre';

	$c->stash->{scores} = $c->stash->{artist}->entrys->search(\%s, {
		prefetch => 'event',
		order_by => [
			{ -desc  => 'event.created' },
			{ -desc => 'score' },
		]
	});

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

	$c->stash->{title} = 'Score Breakdown for ' . $c->stash->{artist}->name;
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
				$c->res->body('Okay');
		}
		else {
			$c->res->redirect($c->req->referer);
		}
	}
	else {
		$c->detach('/error');
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
