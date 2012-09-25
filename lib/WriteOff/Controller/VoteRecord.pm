package WriteOff::Controller::VoteRecord;
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller'; }

=head1 NAME

WriteOff::Controller::VoteRecord - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=head2 index

Grabs a vote record.

=cut

sub index :PathPart('voterecord') :Chained('/') :CaptureArgs(1) {
	my ( $self, $c, $id ) = @_;
	
	$c->stash->{record} = $c->model('DB::VoteRecord')->find($id) or 
		$c->detach('/default');
	
	$c->stash->{record}->event->is_organised_by( $c->user ) or
		$c->detach('/forbidden', ["You are not an organiser for this event."]);

}

sub view :PathPart('') :Chained('index') :Args(0) {
	my ( $self, $c ) = @_;

	$c->stash->{template} = 'voterecord/view.tt';
}

sub delete :PathPart('delete') :Chained('index') :Args(0) {
	my ( $self, $c ) = @_;
	
	$c->stash->{identifier} = 'standard deviation';
	$c->stash->{template} = 'delete.tt';
	
	$c->forward('do_delete') if $c->req->method eq 'POST';
}

sub do_delete :Private {
	my ( $self, $c ) = @_;
	
	$c->form(
		'standard deviation' => [ 
			'NOT_BLANK', 
			[ 'IN_ARRAY', sprintf '%.2f', $c->stash->{record}->votes->stdev ] 
		],
		sessionid => [ 'NOT_BLANK', [ 'IN_ARRAY', $c->sessionid ] ],
	);
	
	if( !$c->form->has_error ) {
		$c->stash->{record}->votes->delete;
		$c->flash->{status_msg} = 'Deletion successful';
		$c->res->redirect( $c->req->params->{referer} || $c->uri_for('/') );	
	}
	else {
		$c->stash->{error_msg} = 'Standard deviation is incorrect';
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
