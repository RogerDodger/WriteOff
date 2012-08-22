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

Grabs a fic

=cut

sub index :PathPart('fic') :Chained('/') :CaptureArgs(1) {
    my ( $self, $c, $id ) = @_;
	
	$c->stash->{story} = $c->model('DB::Story')->find($id) or $c->detach('/default');
}


=head2 submit

=cut

sub submit :PathPart('submit') :Chained('/event/fic') :Args(0) {
	my ( $self, $c ) = @_;
	
	$c->stash->{template} = 'fic/submit.tt';
	
	$c->forward('do_submit') if $c->req->method eq 'POST' && $c->user;
}

sub do_submit :Private {
	my ( $self, $c ) = @_;
	
	my $rs = $c->model('DB::Story');
	
	$c->req->params->{related} = $c->stash->{images}
		->search({ id => $c->req->params->{image_id} })->count if
		$c->stash->{event}->has_art;
	$c->req->params->{wordcount} = $self->wordcount( $c->req->params->{story} );
	
	$c->form(
		title     => [ ['LENGTH', 1, $c->config->{len}->{max}->{title}], 
			'NOT_BLANK', ['DBIC_UNIQUE', $rs, 'title'] ],
		author    => [ ['LENGTH', 1, $c->config->{len}->{max}->{user}] ],
		website   => [  'HTTP_URL'  ],
		related   => [ ['NOT_EQUAL_TO', 0] ],
		wordcount => [ ['BETWEEN', $c->config->{len}->{min}->{fic}, 
			$c->config->{len}->{max}->{fic}] ],
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

sub view :Local :Args(1) {
	my ( $self, $c, $id ) = @_;
	
	my $row = $c->model('DB::Story')->find($id) or $c->detach('/default');
	
	unless( $c->req->params->{plain} ) {		
		my $bb = Parse::BBCode->new;
		my $story = Encode::decode('utf8', $bb->render( $row->contents ) );
		   $story =~ s#\[hr\] *<br>#<hr>#g;
		   $story =~ s#(.*)<br>#<p>$1</p>#g;
		$c->stash->{story} = $story;
		$c->stash->{title} = [$row->title];
		$c->stash->{template} = 'fic/view.tt';
	} 
	else {
		$c->res->content_type('text/plain; charset=utf-8');
		$c->res->body( Encode::decode('utf8', $row->contents) );
	}
	
}

sub edit :Local :Args(1) {
	my ( $self, $c, $id ) = @_;
	
	my $row = $c->model('DB::Story')->find($id) or $c->detach('/default');
	
	$c->detach('/forbidden', ['You do not own this item.']) unless $c->user && 
		( $c->user->id == $row->user_id || $c->check_user_roles($c->user, qw/admin/) );
	
	$c->stash->{self}     = $c->uri_for("/fic/edit/$id");
	$c->stash->{title}    = $row->title;
	$c->stash->{contents} = Encode::decode('utf8', $row->contents);
	
	if($c->req->method eq 'POST') {
		$c->req->params->{wordcount} = $self->wordcount( $c->req->params->{story} );
		
		$c->form( 
			wordcount => [ ['BETWEEN', $c->config->{len}->{min}->{fic}, 
				$c->config->{len}->{max}->{fic}] ] 
		);
		
		if(!$c->form->has_error) {
			$row->update({
				wordcount => $c->req->params->{wordcount},
				contents  => $c->req->params->{story},
			});
			$c->flash->{status_msg} = 'Edit successful';
			$c->res->redirect( $c->uri_for('/user/me') );
		}
	}
}

sub delete :Local :Args(1) {
	my ( $self, $c, $id ) = @_;
	
	my $row = $c->model('DB::Story')->find($id) or $c->detach('/default');
	
	$c->detach('/forbidden', ['You do not own this item.']) unless $c->user && 
		( $c->user->id == $row->user_id || $c->check_user_roles($c->user, qw/admin/) );
	
	$c->stash->{self} = $c->uri_for("/fic/delete/$id");
	$c->stash->{template} = 'delete.tt';
	
	if($c->req->method eq 'POST') {
		$row->delete;
		
		$c->flash->{status_msg} = 'Deletion successful';
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
