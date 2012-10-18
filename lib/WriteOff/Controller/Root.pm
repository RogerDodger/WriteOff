package WriteOff::Controller::Root;
use Moose;
use namespace::autoclean;
no warnings "uninitialized";

BEGIN { extends 'Catalyst::Controller' }
with 'Catalyst::TraitFor::Controller::reCAPTCHA';

__PACKAGE__->config(namespace => '');

=head1 NAME

WriteOff::Controller::Root - Root Controller for WriteOff

=head1 METHODS

=head2 auto

Logs the request.

Detaches to index if the request is POST with a differing origin.

=cut

sub auto :Private {
	my ( $self, $c ) = @_;
	
	my $so = $c->req->uri->host eq eval { URI->new( $c->req->referer )->host };
	
	$c->log->info( sprintf "Request: %s - %s (%s) - %s" . ( $so ? "" : " - %s" ), 
		$c->req->method, 
		$c->req->address,
		( $c->user ? $c->user->get('username') : 'guest' ),
		$c->req->uri->path,
		$c->req->referer || 'no referer',
	) unless $so && $c->action eq 'art/view';
	
	$c->detach('index') if !$so && $c->req->method eq 'POST';
	
	$c->stash->{now} = $c->model('DB::Event')->now_dt;
}

=head2 index

Lists all active events.

=cut

sub index :Path :Args(0) {
	my ( $self, $c ) = @_;
	
	$c->stash->{events} = $c->model('DB::Event')->active;
	
	$c->stash->{template} = 'index.tt';
}

=head2 archive

Lists all old events.

=cut

sub archive :Local :Args(0) {
	my ( $self, $c ) = @_;
	
	$c->stash->{events} = $c->model('DB::Event')->old;
	
	$c->stash->{title} = 'Event Archive';
	$c->stash->{template} = 'index.tt';
}

=head2 faq

Frequently Asked Questions page

=cut

sub faq :Local :Args(0) {
	my ( $self, $c ) = @_;
	
	$c->stash->{template} = 'faq.tt';
}

=head2 default

Standard 404 error page

=cut

sub default :Path {
	my ( $self, $c ) = @_;
	$c->stash->{template} = '404.tt';
	$c->res->status(404);
}

=head2 forbidden

Standard 403 page

=cut

sub forbidden :Private {
	my ( $self, $c, $msg ) = @_;
	
	$c->stash->{forbidden_msg} = $msg // 'Access denied';
	$c->stash->{template} = '403.tt';
	$c->res->status(403);
}

=head2 error

Error page

=cut

sub error :Private {
	my ( $self, $c, $msg ) = @_;
	
	$c->stash->{error} = $msg // 'Something went wrong';
	$c->stash->{template} = 'error.tt';
	$c->res->status(404);
}

=head2 tos

Terms of Service page

=cut

sub tos :Local :Args(0) {
	my ( $self, $c) = @_;
	
	$c->stash->{template} = 'tos.tt';
}

=head2 assert_admin

Check that the user is the admin, detaching to a 403 if they aren't.

=cut

sub assert_admin :Private {
	my ( $self, $c, $msg ) = @_;
	
	$msg //= 'You are not the admin.';
	$c->detach('/forbidden', [ $msg ]) unless $c->check_user_roles('admin'); 
}

=head2 render

Attempt to render a view, if needed.

=cut

sub render : ActionClass('RenderView') {}

sub end :Private {
	my ( $self, $c ) = @_;
	$c->forward('render');
	$c->fillform( $c->stash->{fillform} ) if defined $c->stash->{fillform};
}

=head1 AUTHOR

Cameron Thornton E<lt>cthor@cpan.orgE<gt>

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
