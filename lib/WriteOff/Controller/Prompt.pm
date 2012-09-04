package WriteOff::Controller::Prompt;
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller'; }

=head1 NAME

WriteOff::Controller::Prompt - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=head2 index

=cut

sub index :PathPart('prompt') :Chained('/') :CaptureArgs(1) {
    my ( $self, $c, $id ) = @_;
	
	$c->stash->{prompt} = $c->model('DB::Prompt')->find($id) or $c->detach('/default');
	
	$c->stash->{user_has_permissions} = $c->user && (
		$c->user->id == $c->stash->{prompt}->user_id ||
		$c->check_user_roles($c->user, qw/admin/) 
	);

}

sub vote :PathPart('vote') :Chained('/event/prompt') :Args(0) {
	my ( $self, $c ) = @_;
	
	$c->stash->{prompts} = $c->stash->{event}->prompts->search(undef,
		{ order_by => { -desc => 'rating' } },
	);
	
	$c->stash->{heat} = $c->model('DB::Heat')->new_heat( $c->stash->{prompts} );
	
	$c->stash->{template} = 'prompt/vote.tt';
	$c->forward('do_vote') if $c->req->method eq 'POST';
}

sub do_vote :Private {
	my ( $self, $c ) = @_;
	
	my $heat = $c->model('DB::Heat')->find( $c->req->params->{heat} ) or
		return 0;
	
	my $result;
	$result //= 1   if $c->req->params->{left};
	$result //= 0.5 if $c->req->params->{tie};
	$result //= 0   if $c->req->params->{right};
	
	$heat->do_heat( $result );
}

sub submit :PathPart('submit') :Chained('/event/prompt') :Args(0) {
	my ( $self, $c ) = @_;
	
	$c->detach('/forbidden', ['Guests cannot submit prompts.']) unless $c->user;
	
	$c->stash->{template} = 'prompt/submit.tt';
	$c->forward('do_submit') if $c->req->method eq 'POST';
}

sub do_submit :Private {
	my ( $self, $c ) = @_;

	my $rs = $c->model('DB::Prompt')->search({ event_id => $c->stash->{event}->id });
	$c->req->params->{limit} = $rs->search({ user_id => $c->user->id })->count;
	
	$c->req->params->{prompt} =~ s/^\s+|\s+$//g;
	$c->req->params->{prompt} =~ s/\s+/ /g;
	
	$c->form(
		prompt       => [  'NOT_BLANK', [ 'DBIC_UNIQUE', $rs, 'contents' ],
			[ 'LENGTH', 1, $c->config->{len}->{max}->{prompt} ] ],
		sessionid    => [  'NOT_BLANK', [ 'IN_ARRAY', $c->sessionid ] ],
		subs_allowed => [ ['EQUAL_TO', 1] ],
		limit        => [ ['LESS_THAN', $c->config->{prompts_per_user}] ],
	);
	
	if( !$c->form->has_error ) {
		
		$rs->create({
			event_id => $c->stash->{event}->id,
			user_id  => $c->user->id,
			contents => $c->req->params->{prompt},
			rating   => $c->config->{elo_base},
		});
		
		$c->res->redirect( $c->uri_for('/user/me') );
	}
}

sub delete :PathPart('delete') :Chained('index') :Args(0) {
	my ( $self, $c ) = @_;
	
	$c->detach('/forbidden', ['You do not own this item.']) unless 
		$c->stash->{user_has_permissions};
	
	$c->stash->{self} = $c->uri_for("/prompt/" . $c->stash->{prompt}->id . "/delete");
	$c->stash->{template} = 'delete.tt';
	
	if( $c->req->method eq 'POST' ) {
		if( $c->req->params->{sessionid} eq $c->sessionid ) {
			$c->stash->{prompt}->delete;
			$c->flash->{status_msg} = 'Deletion successful';
		}
		else {
			$c->flash->{error_msg} = 'Invalid session';
		}
		$c->res->redirect( $c->uri_for('/user/me') );	
	}
}

=head1 AUTHOR

Cameron Thornton

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
