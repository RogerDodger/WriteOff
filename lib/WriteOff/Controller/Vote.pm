package WriteOff::Controller::Vote;
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller'; }

=head1 NAME

WriteOff::Controller::Vote - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut

sub prelim :PathPart('vote/prelim') :Chained('/event/fic') :Args(0) {
    my ( $self, $c ) = @_;
	
	$c->detach('/error', [ "There is no prelim for this event." ]) 
		unless $c->stash->{event}->prelim;
	
	push $c->stash->{title}, 'Vote', 'Prelim';
	$c->stash->{template} = 'vote/prelim.tt';
}

sub private :PathPart('vote/private') :Chained('/event/fic') :Args(0) {
    my ( $self, $c ) = @_;
	
	$c->detach('/error', [ "There is no private judging for this event." ]) 
		unless $c->stash->{event}->private;
	
	push $c->stash->{title}, 'Vote', 'Private';
	$c->stash->{template} = 'vote/private.tt';
}


=head1 AUTHOR

Cameron Thornton E<lt>cthor@cpan.orgE<gt>

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
