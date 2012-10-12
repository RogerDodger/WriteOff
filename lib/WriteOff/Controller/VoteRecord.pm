package WriteOff::Controller::VoteRecord;
use Moose;
use namespace::autoclean;
no warnings "uninitialized";

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
	
	$c->detach('/forbidden', [ "Guests cannot manipulate voterecords." ])
		unless $c->user;
	
	$c->stash->{record} = $c->model('DB::VoteRecord')->find($id) or 
		$c->detach('/default');
	
	$c->stash->{event} = $c->stash->{record}->event;
}

sub view :PathPart('') :Chained('index') :Args(0) {
	my ( $self, $c ) = @_;

	$c->forward('/default') unless $c->stash->{record}->is_filled;
	$c->forward( $c->controller('Event')->action_for('assert_organiser') );
	
	$c->stash->{template} = 'voterecord/view.tt';
}

sub delete :PathPart('delete') :Chained('index') :Args(0) {
	my ( $self, $c ) = @_;
	
	$c->forward('/default') unless $c->stash->{record}->is_filled;
	$c->forward( $c->controller('Event')->action_for('assert_organiser') );
	
	$c->stash->{key} = { 
		name  => 'standard deviation (to 2 decimal places)',
		value => sprintf "%.2f", $c->stash->{record}->stdev,
	};
	
	$c->stash->{template} = 'delete.tt';
	
	$c->forward('do_delete') if $c->req->param('sessionid') eq $c->sessionid;
}

sub do_delete :Private {
	my ( $self, $c ) = @_;

	$c->log->info( sprintf "VoteRecord deleted by %s: %s (%s)",
		$c->user->get('username'),
		$c->stash->{record}->ip,
		eval { $c->stash->{record}->user->username } || 'Guest',
	);
	
	$c->stash->{record}->votes->delete_all;
	
	$c->flash->{status_msg} = 'Deletion successful';
	$c->res->redirect( $c->req->param('referer') || $c->uri_for('/') );
}


=head1 AUTHOR

Cameron Thornton E<lt>cthor@cpan.orgE<gt>

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
