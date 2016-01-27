package WriteOff::Controller::Artist;
use Moose;
use namespace::autoclean;
use Scalar::Util qw/looks_like_number/;

BEGIN { extends 'Catalyst::Controller'; }

__PACKAGE__->config(model => 'Artist');

sub fetch :Chained('/') :PathPart('artist') :CaptureArgs(1) :ActionClass('~Fetch') {}

sub scores :Chained('fetch') :PathPart('scores') :Args(0) {
	my ( $self, $c ) = @_;

	my $s = {};
	$s->{genre_id} = $1 if $c->req->param('genre') =~ /^(\d+)/;
	$s->{format_id} = $1 if $c->req->param('format') =~ /^(\d+)/;

	$c->stash->{scores} = $c->stash->{artist}->entrys->search($s, {
		prefetch => 'event',
		order_by => [
			{ -desc  => 'event.created' },
			{ -desc => 'score' },
		]
	});

	$c->stash->{scoreKey} = $s->{format_id} ? 'score_format' : 'score_genre';

	$c->stash->{title} = 'Score Breakdown for ' . $c->stash->{artist}->name;
	$c->stash->{template} = 'scoreboard/scores.tt';
}

sub swap :Local {
	my ($self, $c) = @_;

	return unless $c->req->method eq 'POST';

	$c->forward('/check_csrf_token');

	my $id = $c->req->param('artist');
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
