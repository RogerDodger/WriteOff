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
    my ( $self, $c, $arg ) = @_;
	
	my $id = eval { no warnings; int $arg };
	$c->stash->{prompt} = $c->model('DB::Prompt')->find($id) or 
		$c->detach('/default');
		
	if( $arg ne $c->stash->{prompt}->id_uri ) {
		$c->res->redirect
		( $c->uri_for( $c->action, [ $c->stash->{prompt}->id_uri ] ) );
	}
}

sub vote :PathPart('vote') :Chained('/event/prompt') :Args(0) {
	my ( $self, $c ) = @_;
	
	$c->stash->{prompts} = $c->stash->{event}->prompts->search(undef,
		{ order_by => { -desc => 'rating' } } 
	);
	
	$c->stash->{template} = 'prompt/vote.tt';
	
	if ( $c->stash->{event}->prompt_votes_allowed ) {
		$c->forward('do_vote') if $c->req->method eq 'POST';
		
		$c->stash->{heat} = $c->model('DB::Heat')->get_or_new_heat
		( $c->stash->{event}, $c->req->address );
	}
}

sub do_vote :Private {
	my ( $self, $c ) = @_;
	
	my $heat = $c->model('DB::Heat')->find( $c->req->params->{heat} ) or
		return 0;
	
	my $result;
	$result //= 1   if $c->req->params->{left};
	$result //= 0.5 if $c->req->params->{tie};
	$result //= 0   if $c->req->params->{right};
	
	$heat->do_heat( $c->stash->{event}, $c->req->address, $result );
}

sub submit :PathPart('submit') :Chained('/event/prompt') :Args(0) {
	my ( $self, $c ) = @_;
	
	$c->stash->{template} = 'prompt/submit.tt';
	
	$c->forward('do_submit') if $c->req->method eq 'POST' && 
		$c->user && $c->stash->{event}->prompt_subs_allowed;
}

sub do_submit :Private {
	my ( $self, $c ) = @_;

	my $rs = $c->stash->{event}->prompts;
	
	$c->req->params->{count} = $rs->search({ user_id => $c->user->id })->count;
	
	$c->form(
		prompt       => [ 
			'NOT_BLANK',
			[ 'LENGTH', 1, $c->config->{len}{max}{prompt} ], 
			'TRIM_COLLAPSE', 
			[ 'DBIC_UNIQUE', $rs, 'contents' ],
		],
		sessionid    => [ 'NOT_BLANK', [ 'IN_ARRAY', $c->sessionid ] ],
		count        => [ [ 'LESS_THAN', $c->config->{prompts_per_user} ] ],
	);
	
	if( !$c->form->has_error ) {
		
		$rs->create({
			event_id => $c->stash->{event}->id,
			user_id  => $c->user->id,
			ip       => $c->req->address,
			contents => $c->form->valid('prompt'),
			rating   => $c->config->{elo_base},
		});

		$c->stash->{status_msg} = 'Submission successful';
	}
}

sub delete :PathPart('delete') :Chained('index') :Args(0) {
	my ( $self, $c ) = @_;
	
	$c->detach('/forbidden', ['You cannot delete this item.']) unless 
		$c->stash->{prompt}->is_manipulable_by( $c->user );
		
	$c->stash->{template} = 'delete.tt';
	
	$c->forward('do_delete') if $c->req->method eq 'POST';
}

sub do_delete :Private {
	my ( $self, $c ) = @_;
	
	$c->form(
		title => [ 'NOT_BLANK', [ 'IN_ARRAY', $c->stash->{prompt}->contents ] ],
		sessionid => [ 'NOT_BLANK', [ 'IN_ARRAY', $c->sessionid ] ],
	);
	
	if( !$c->form->has_error ) {
		$c->stash->{prompt}->delete;
		$c->flash->{status_msg} = 'Deletion successful';
		$c->res->redirect( $c->uri_for('/user/me') );	
	}
	else {
		$c->stash->{error_msg} = 'Title is incorrect';
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
