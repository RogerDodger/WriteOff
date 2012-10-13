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
	
	$c->detach('/error', [ "There is no preliminary voting round for this event." ]) 
		unless $c->stash->{event}->prelim;
	
	$c->stash->{records} = $c->stash->{event}->vote_records->unfilled->search({
		round   => 'prelim',
		user_id => $c->user->get('id'),
	}) if $c->user;
	
	push $c->stash->{title}, 'Vote', 'Prelim';
	$c->stash->{template} = 'vote/prelim.tt';
	
	$c->stash->{error_msg} = $c->forward('prelim_request') 
		if $c->user && $c->req->method eq 'POST';
}

sub prelim_request :Private {
	my ( $self, $c ) = @_;
	
	return "You have empty records to fill in" if $c->stash->{records}->count;
	
	return $c->stash->{event}->new_prelim_record_for( $c->user, $c->config->{prelim_distr_size} );
	
	0;
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
