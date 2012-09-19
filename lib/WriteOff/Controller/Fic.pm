package WriteOff::Controller::Fic;
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller'; }

=head1 NAME

WriteOff::Controller::Fic - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut

=head2 index :PathPart('fic') :Chained('/') CaptureArgs(1)

Grabs a story

=cut

sub index :PathPart('fic') :Chained('/') :CaptureArgs(1) {
    my ( $self, $c, $arg ) = @_;
	
	my $id = eval { no warnings; int $arg };
	$c->stash->{story} = $c->model('DB::Story')->find($id) or 
		$c->detach('/default');
	
	if( $arg ne $c->stash->{story}->id_uri ) {
		$c->res->redirect
		( $c->uri_for( $c->action, [ $c->stash->{story}->id_uri ] ) );
	}
}

sub submit :PathPart('submit') :Chained('/event/fic') :Args(0) {
	my ( $self, $c ) = @_;
	
	$c->stash->{template} = 'fic/submit.tt';
	$c->forward('do_submit') if $c->req->method eq 'POST' && 
		$c->user && $c->stash->{event}->fic_subs_allowed;
}

sub do_submit :Private {
	my ( $self, $c ) = @_;

	$c->req->params->{wordcount} = $c->wordcount( $c->req->params->{story} );
	
	$c->form(
		title        => [ 
			[ 'LENGTH', 1, $c->config->{len}{max}{title} ], 
			'TRIM_COLLAPSE', 
			'NOT_BLANK', 
			[ 'DBIC_UNIQUE', $c->model('DB::Story'), 'title' ],
		],
		author       => [ 
			[ 'LENGTH', 1, $c->config->{len}{max}{user} ],
			'TRIM_COLLAPSE', 
		],
		website      => [ 'HTTP_URL' ],
		image_id     => [ 
			( $c->stash->{event}->art ? 'NOT_BLANK' : () ),
			[ 'IN_ARRAY', $c->stash->{event}->images->get_column('id')->all ],
		],
		story        => [ 'NOT_BLANK' ],
		wordcount    => [ [ 'BETWEEN', $c->stash->{event}->wc_min, 
			$c->stash->{event}->wc_max ] ],
	);
	
	if(!$c->form->has_error) {
		
		my $new = $c->model('DB::Story')->create({
			event_id  => $c->stash->{event}->id,
			user_id   => $c->user->id,
			ip        => $c->req->address,
			title     => $c->form->valid('title'),
			author    => $c->form->valid('author') || 'Anonymous',
			website   => $c->form->valid('website') || undef,
			contents  => $c->form->valid('story'),
			wordcount => $c->form->valid('wordcount'),
			seed      => rand,
		});
		
		$c->model('DB::ImageStory')->create({
			story_id => $new->id,
			image_id => $c->form->valid->{image_id},
		}) if $c->stash->{event}->art;
		
		$c->flash->{status_msg} = 'Submission successful';
		$c->res->redirect( $c->req->referer || $c->uri_for('/') );
	}
}

sub view :PathPart('') :Chained('index') :Args(0) {
	my ( $self, $c ) = @_;
	
	if( $c->req->params->{plain} ) {
		$c->res->content_type('text/plain; charset=utf-8');
		$c->res->body( $c->stash->{story}->contents );
	}
	
	$c->stash->{template} = 'fic/view.tt';
}

sub gallery :PathPart('gallery') :Chained('/event/fic') :Args(0) {
	my ( $self, $c ) = @_;
	
	$c->stash->{template} = 'fic/gallery.tt';
}

sub edit :PathPart('edit') :Chained('index') :Args(0) {
	my ( $self, $c ) = @_;
	
	$c->detach('/forbidden', ['You cannot edit this item.']) unless 
		$c->stash->{story}->is_manipulable_by( $c->user );
	
	$c->stash->{template} = 'fic/edit.tt';
	
	$c->forward('do_edit') if $c->req->method eq 'POST';
}

sub do_edit :Private {
	my ( $self, $c ) = @_;
	
	$c->req->params->{wordcount} = $c->wordcount( $c->req->params->{story} );
	
	$c->form( 
		story     => [ 'NOT_BLANK' ],
		wordcount => [ ['BETWEEN', $c->stash->{story}->event->wc_min, 
			$c->stash->{story}->event->wc_max] ],
		sessionid => [ 'NOT_BLANK', [ 'IN_ARRAY', $c->sessionid ] ],
	);
	
	if( !$c->form->has_error ) {
	
		$c->stash->{story}->update({
			wordcount => $c->form->valid('wordcount'),
			contents  => $c->form->valid('story'),
		});
		
		$c->stash->{status_msg} = 'Edit successful';
	}
	
}

sub delete :PathPart('delete') :Chained('index') :Args(0) {
	my ( $self, $c ) = @_;
	
	$c->detach('/forbidden', ['You cannot delete this item.']) unless 
		$c->stash->{story}->is_manipulable_by( $c->user );
		
	$c->stash->{template} = 'delete.tt';
	
	$c->forward('do_delete') if $c->req->method eq 'POST';
}

sub do_delete :Private {
	my ( $self, $c ) = @_;
	
	$c->form(
		title     => [ 'NOT_BLANK', [ 'IN_ARRAY', $c->stash->{story}->title ] ],
		sessionid => [ 'NOT_BLANK', [ 'IN_ARRAY', $c->sessionid ] ],
	);
	
	if( !$c->form->has_error ) {
		$c->stash->{story}->delete;
		$c->flash->{status_msg} = 'Deletion successful';
		$c->res->redirect( $c->uri_for('/user/me') );	
	}
	else {
		$c->stash->{error_msg} = 'Title is incorrect';
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
