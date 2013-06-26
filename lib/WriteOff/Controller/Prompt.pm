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
	
	(my $id = $arg) =~ s/^\d+\K.*//;
	$c->stash->{prompt} = $c->model('DB::Prompt')->find($id) or 
		$c->detach('/default');
		
	if( $arg ne $c->stash->{prompt}->id_uri ) {
		$c->res->redirect
		( $c->uri_for( $c->action, [ $c->stash->{prompt}->id_uri ] ) );
	}
	
	push $c->stash->{title}, [ $c->stash->{prompt}->contents ];
}

sub vote :PathPart('vote') :Chained('/event/prompt') :Args(0) {
	my ( $self, $c ) = @_;
	
	$c->stash->{prompts} = $c->stash->{event}->prompts->search(undef,
		{ order_by => { -desc => 'rating' } } 
	);
	
	if ( $c->stash->{event}->prompt_votes_allowed ) {
		$c->forward('do_vote') if $c->req->method eq 'POST';
		
		$c->stash->{heat} = $c->model('DB::Heat')->get_or_new_heat
		( $c->stash->{event}, $c->req->address );
	}
	
	$c->stash->{template} = 'prompt/vote.tt';
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
	
	my $subs_left = sub {
		return 0 unless $c->user;
		return $c->config->{prompts_per_user} -
		$c->stash->{event}->prompts->search({ user_id => $c->user_id })->count;
	};
	
	$c->req->params->{subs_left} = $subs_left->();
	
	$c->forward('do_submit') 
		if $c->req->method eq 'POST' 
		&& $c->user_exists
		&& $c->stash->{event}->prompt_subs_allowed;
		
	$c->stash->{subs_left} = $subs_left->();
		
	push $c->stash->{title}, 'Submit';
	$c->stash->{template} = 'prompt/submit.tt';
}

sub do_submit :Private {
	my ( $self, $c ) = @_;

	$c->forward('/check_csrf_token');
	
	$c->form(
		prompt => [ 
			'NOT_BLANK',
			[ 'LENGTH', 1, $c->config->{len}{max}{prompt} ], 
			'TRIM_COLLAPSE', 
			[ 'DBIC_UNIQUE', $c->stash->{event}->prompts_rs, 'contents' ],
		],
		subs_left => [ [ 'GREATER_THAN', 0 ] ],
	);
	
	if( !$c->form->has_error ) {
		
		$c->stash->{event}->create_related('prompts', {
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
		
	$c->stash->{key} = { 
		name  => 'prompt',
		value => $c->stash->{prompt}->contents,
	};
		
	$c->forward('do_delete') if $c->req->method eq 'POST';
	
	push $c->stash->{title}, 'Delete';
	$c->stash->{template} = 'item/delete.tt';
}

sub do_delete :Private {
	my ( $self, $c ) = @_;
	
	$c->forward('/check_csrf_token');
	
	$c->log->info( sprintf "Prompt deleted by %s: %s (%s - %s)",
		$c->user->get('username'),
		$c->stash->{prompt}->contents,
		$c->stash->{prompt}->ip,
		$c->stash->{prompt}->user->username,
	);
		
	$c->stash->{prompt}->delete;
		
	$c->flash->{status_msg} = 'Deletion successful';
	$c->res->redirect( $c->req->param('referer') || $c->uri_for('/') );
}

=head1 AUTHOR

Cameron Thornton

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
