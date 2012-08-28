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
    my ( $self, $c, $id ) = @_;
	
	$c->stash->{story} = $c->model('DB::Story')->find($id) or $c->detach('/default');
	
	$c->stash->{user_has_permissions} = $c->user && (
		$c->user->id == $c->stash->{story}->user_id ||
		$c->check_user_roles($c->user, qw/admin/) 
	);
	
	$c->req->params->{subs_allowed} = 
		$c->model('DB::Event')->fic_subs_allowed( $c->stash->{story}->event_id );
}

sub submit :PathPart('submit') :Chained('/event/fic') :Args(0) {
	my ( $self, $c ) = @_;
	
	$c->stash->{template} = 'event/fic_submit.tt';
	
	$c->forward('do_submit') if $c->req->method eq 'POST' && $c->user;
}

sub do_submit :Private {
	my ( $self, $c ) = @_;
	
	my $rs = $c->model('DB::Story');
	
	$c->req->params->{related} = 
		$c->stash->{images}->search({ id => $c->req->params->{image_id} })->count if
		$c->stash->{event}->has_art;
	$c->req->params->{wordcount} = $self->wordcount( $c->req->params->{story} );
	
	$c->form(
		title        => [ ['LENGTH', 1, $c->config->{len}->{max}->{title}], 
			'NOT_BLANK', ['DBIC_UNIQUE', $rs, 'title'] ],
		author       => [ ['LENGTH', 1, $c->config->{len}->{max}->{user}] ],
		website      => [  'HTTP_URL'  ],
		related      => [ ['NOT_EQUAL_TO', 0] ],
		wordcount    => [ ['BETWEEN', $c->config->{len}->{min}->{fic}, 
			$c->config->{len}->{max}->{fic}] ],
		subs_allowed => [ ['EQUAL_TO', 1] ],
	);
	
	if(!$c->form->has_error) {
		
		my $row = $c->model('DB::Story')->create({
			event_id  => $c->stash->{event}->id,
			title     => $c->req->params->{title},
			user_id   => $c->user->id,
			author    => $c->req->params->{author} || 'Anonymous',
			website   => $c->req->params->{website} || undef,
			contents  => $c->req->params->{story},
			wordcount => $c->req->params->{wordcount},
		});
		
		if( $c->stash->{event}->has_art ) {
			$c->model('DB::ImageStory')->create({
				story_id => $row->id,
				image_id => $c->req->params->{image_id},
			});
		}
		
		$c->stash->{template} = 'submission_successful.tt';
		$c->stash->{redirect} = $c->req->referer || $c->uri_for('/');
	}
}

sub view :PathPart('view') :Chained('index') :Args(0) {
	my ( $self, $c ) = @_;
	
	unless( $c->req->params->{plain} ) {		
		my $bb = Parse::BBCode->new;
		my $contents = Encode::decode
		   ( 'utf8', $bb->render( $c->stash->{story}->contents ) );
		   $contents =~ s#\[hr\] *<br>#<hr>#g;
		   $contents =~ s#(.*)<br>#<p>$1</p>#g;
		$c->stash->{contents} = $contents;
		$c->stash->{title} = $c->stash->{story}->title;
		$c->stash->{template} = 'fic/view.tt';
	} 
	else {
		$c->res->content_type('text/plain; charset=utf-8');
		$c->res->body( Encode::decode('utf8', $c->stash->{story}->contents) );
	}
	
}

sub edit :PathPart('edit') :Chained('index') :Args(0) {
	my ( $self, $c ) = @_;
	
	$c->detach('/forbidden', ['You do not own this item.']) unless 
		$c->stash->{user_has_permissions};
		
	if ( !$c->req->params->{subs_allowed} ) {
		$c->flash->{error_msg} = "Item cannot be edited: Submissions disabled";
		$c->res->redirect( $c->uri_for('/user/me') );
	}
	
	$c->stash->{self}     = $c->uri_for("/fic/" . $c->stash->{story}->id . "/edit");
	$c->stash->{title}    = $c->stash->{story}->title;
	$c->stash->{contents} = Encode::decode('utf8', $c->stash->{story}->contents);
	
	if($c->req->method eq 'POST' ) {
		$c->req->params->{wordcount} = $self->wordcount( $c->req->params->{story} );
		
		$c->form( 
			wordcount => [ ['BETWEEN', $c->config->{len}->{min}->{fic}, 
				$c->config->{len}->{max}->{fic}] ],
			sessionid => [ 'NOT_BLANK', ['IN_ARRAY', $c->sessionid] ],
			subs_allowed => [ ['EQUAL_TO', 1] ],
		);
		
		if(!$c->form->has_error) {
			$c->stash->{story}->update({
				wordcount => $c->req->params->{wordcount},
				contents  => $c->req->params->{story},
			});
			$c->flash->{status_msg} = 'Edit successful';
			$c->res->redirect( $c->uri_for('/user/me') );
		}
	}
}

sub delete :PathPart('delete') :Chained('index') :Args(0) {
	my ( $self, $c ) = @_;
	
	$c->detach('/forbidden', ['You do not own this item.']) unless 
		$c->stash->{user_has_permissions};
	
	$c->stash->{self} = $c->uri_for("/fic/" . $c->stash->{story}->id . "/delete");
	$c->stash->{template} = 'delete.tt';
	
	if( $c->req->method eq 'POST' ) {
		if( $c->req->params->{sessionid} eq $c->sessionid ) {
			$c->stash->{story}->delete;
			$c->flash->{status_msg} = 'Deletion successful';
		}
		else {
			$c->flash->{error_msg} = 'Invalid session';
		}
		$c->res->redirect( $c->uri_for('/user/me') );	
	}
}

sub wordcount {
	my ( $self, $str ) = @_;
	$str =~ s#\[/?(.+)\]#$1#g;
	return scalar split /[^\w\-']+/, $str;
}

=head1 AUTHOR

Cameron Thornton

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
