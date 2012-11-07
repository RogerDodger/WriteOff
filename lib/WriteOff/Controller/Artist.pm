package WriteOff::Controller::Artist;
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller'; }

=head1 NAME

WriteOff::Controller::Artist - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=head2 index

Grabs an artist

=cut

sub index :Chained('/') :PathPart('artist') :CaptureArgs(1) {
	my ( $self, $c, $id ) = @_;
	
	$c->stash->{artist} = $c->model('DB::Artist')->find($id)
		or $c->detach('/default');
}

=head2 scores

Displays the scores for an artist.

=cut

sub scores :Chained('index') :PathPart('scores') :Args(0) {
	my ( $self, $c ) = @_;
	
	$c->stash->{scores} = $c->stash->{artist}->scores->search(undef, {
		prefetch => 'event',
		order_by => [
			{ -asc  => 'event.end' },
			{ -desc => 'value' },
		]
	});
	
	$c->stash->{title} = 'Score Breakdown for ' . $c->stash->{artist}->name;
	$c->stash->{template} = 'scoreboard/scores.tt';
}

=head1 AUTHOR

Cameron Thornton E<lt>cthor@cpan.orgE<gt>

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
