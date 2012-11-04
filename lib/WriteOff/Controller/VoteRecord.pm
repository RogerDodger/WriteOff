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

sub begin :Private {
	my ( $self, $c ) = @_;
	
	$c->stash->{title} = [ 'Vote Record' ];
}

sub index :PathPart('voterecord') :Chained('/') :CaptureArgs(1) {
	my ( $self, $c, $id ) = @_;
	
	$c->detach('/forbidden', [ "Guests cannot manipulate voterecords." ])
		unless $c->user;
	
	$c->stash->{record} = $c->model('DB::VoteRecord')->find($id) or 
		$c->detach('/default');
	
	$c->stash->{event} = $c->stash->{record}->event;
	push $c->stash->{title}, $id;
}

sub view :PathPart('') :Chained('index') :Args(0) {
	my ( $self, $c ) = @_;

	$c->detach('/default') unless $c->stash->{record}->is_filled;
	$c->forward( $c->controller('Event')->action_for('assert_organiser') );
	
	$c->stash->{template} = 'voterecord/view.tt';
}

sub delete :PathPart('delete') :Chained('index') :Args(0) {
	my ( $self, $c ) = @_;
	
	$c->detach('/default') unless $c->stash->{record}->is_filled;
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

sub fill :PathPart('fill') :Chained('index') :Args(0) {
	my ( $self, $c ) = @_;
	
	$c->detach('/forbidden', [ "You do not own this record." ])
		unless $c->stash->{record}->user_id == $c->user->id;
	$c->detach('/error', [ "This record is already filled." ]) 
		unless $c->stash->{record}->is_unfilled;
		
	$c->detach('/error', [ "It is too late to fill this record." ])
		if $c->stash->{record}->round eq 'prelim' 
			&& !$c->stash->{event}->prelim_votes_allowed
		|| $c->stash->{record}->round eq 'private' 
			&& !$c->stash->{event}->private_votes_allowed;
	
	push $c->stash->{title}, 'Fill';
	$c->stash->{template} = 'voterecord/fill.tt';
	
	$c->forward('do_fill') if $c->req->method eq 'POST' 
		&& $c->req->param('sessionid') eq $c->sessionid;
}

sub do_fill :Private {
	my ( $self, $c ) = @_;
	
	my @params = split ";", $c->req->param('data');
	my $vote_ids = $c->stash->{record}->votes->get_column('id');
	
	return 0 unless [ $vote_ids->all ] ~~ [ sort { $a <=> $b } @params ];
	
	for( my $p = 0; $p <= $#params; $p++ ) {
		$c->model('DB::Vote')->find( $params[$p] )->update({
			value => $#params - 2 * $p,
		});
	}
	
	$c->stash->{record}->update({ ip => $c->req->address });
	
	$c->flash->{status_msg} = 'Vote successful';
	$c->res->redirect( $c->uri_for( $c->controller('Vote')->action_for
			( $c->stash->{record}->round ), [ $c->stash->{event}->id ]) );
}

=head1 AUTHOR

Cameron Thornton E<lt>cthor@cpan.orgE<gt>

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
