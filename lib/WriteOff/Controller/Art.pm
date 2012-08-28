package WriteOff::Controller::Art;
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller'; }

=head1 NAME

WriteOff::Controller::Art - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut

=head2 index :PathPart('art') :Chained('/') CaptureArgs(1)

Grabs an image

=cut

sub index :PathPart('art') :Chained('/') :CaptureArgs(1) {
    my ( $self, $c, $id ) = @_;
	
	$c->stash->{image} = $c->model('DB::Image')->find($id) or $c->detach('/default');
	
	$c->stash->{user_has_permissions} = $c->user && (
		$c->user->id == $c->stash->{image}->user_id ||
		$c->check_user_roles($c->user, qw/admin/) 
	);
}

sub submit :PathPart('submit') :Chained('/event/art') :Args(0) {
	my ( $self, $c ) = @_;
	
	$c->stash->{template} = 'event/art_submit.tt';
	
	$c->forward('/captcha_get');
	$c->forward('do_submit') if $c->req->method eq 'POST';
}

sub do_submit :Private {
	my ( $self, $c ) = @_;

	my $rs = $c->model('DB::Image');
	$c->req->params->{captcha} = $c->user && 1 || $c->forward('/captcha_check');
	my $img = $c->req->upload('image');
	if($img) {
		$c->req->params->{image}    = 1;
		$c->req->params->{mimetype} = $img->mimetype;
		$c->req->params->{filesize} = $img->size;
	} 
	else {
		delete $c->req->params->{image};
	}
	
	$c->form(
		title        => [ ['LENGTH', 1, $c->config->{len}->{max}->{title}], 
			'NOT_BLANK', ['DBIC_UNIQUE', $rs, 'title'] ],
		artist       => [ ['LENGTH', 1, $c->config->{len}->{max}->{user}] ],
		website      => [  'HTTP_URL'  ],
		image        => [  'NOT_BLANK' ],
		mimetype     => [ ['IN_ARRAY', @{ $c->config->{allowed_types} }] ],
		captcha      => [ ['EQUAL_TO', 1] ],
		filesize     => [ ['LESS_THAN', $c->config->{len}->{max}->{img}] ],
		subs_allowed => [ ['EQUAL_TO', 1] ],
	);
	
	if(!$c->form->has_error) {
		
		my %row = (
			filesize => $img->size,
			mimetype => $img->mimetype,
			event_id => $c->stash->{event}->id,
			title    => $c->req->params->{title},
			artist   => $c->req->params->{artist} || 'Anonymous',
			website  => $c->req->params->{website} || undef,
		);
		$row{user_id} = $c->user->id if $c->user;
		
		my $magick = Image::Magick->new;
		$magick->Read     ( $img->tempname );
		$row{contents} =  ( $magick->ImageToBlob )[0];
		
		$magick->Resize( geometry => '250x250' );
		$row{thumb} =  ( $magick->ImageToBlob  )[0];
		
		$rs->create(\%row);
		$c->stash->{template} = 'submission_successful.tt';
		$c->stash->{redirect} = $c->req->referer || $c->uri_for('/');
	}
}

sub view :PathPart('view') :Chained('index') :Args(0) {
	my ( $self, $c ) = @_;
	
	$c->res->content_type( $c->stash->{image}->mimetype );
	$c->res->body( 
		$c->req->params->{thumb} ? 
		$c->stash->{image}->thumb : 
		$c->stash->{image}->contents 
	);
}

sub delete :PathPart('delete') :Chained('index') :Args(0) {
	my ( $self, $c ) = @_;
	
	$c->detach('/forbidden', ['You do not own this item.']) unless
		$c->stash->{user_has_permissions};
	
	$c->stash->{self} = $c->uri_for("/art/" . $c->stash->{image}->id . "/delete");
	$c->stash->{template} = 'delete.tt';
	
	if( $c->req->method eq 'POST' ) {
		if( $c->req->params->{sessionid} eq $c->sessionid ) {
			$c->stash->{image}->delete;
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
