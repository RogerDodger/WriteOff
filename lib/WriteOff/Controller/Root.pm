package WriteOff::Controller::Root;
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller' }
with 'Catalyst::TraitFor::Controller::reCAPTCHA';

__PACKAGE__->config(namespace => '');

=head1 NAME

WriteOff::Controller::Root - Root Controller for WriteOff

=head1 METHODS

=cut

sub begin :Private {
	my ( $self, $c ) = @_;

	$c->log->info( sprintf "Request: %s - %s (%s) - %s", 
		$c->req->method, 
		$c->req->address,
		( $c->user ? $c->user->get('username') : 'guest' ),
		$c->req->uri->path,
	);
	
	if( $c->req->method eq 'POST' ) {
		my $root = $c->uri_for('/');
		$c->detach('index') if ($c->req->referer || '') !~ /^$root/;
	}
}

sub auto :Private {
	my ( $self, $c ) = @_;
	
	$c->stash->{now} = $c->model('DB::Event')->now_dt;
}

=head2 index

The root page (/)

=cut

sub index :Path :Args(0) {
	my ( $self, $c ) = @_;
	
	$c->stash->{events} = $c->model('DB::Event')->active_events;
	
    $c->stash->{template} = 'index.tt';
}

sub archive :Local :Args(0) {
	my ( $self, $c ) = @_;
	
	$c->stash->{events} = $c->model('DB::Event')->old_events;
	
    $c->stash->{template} = 'index.tt';
}

sub faq :Local :Args(0) {
	my ( $self, $c ) = @_;
	
	$c->stash->{template} = 'faq.tt';
}

sub scoreboard :Local :Args(0) {
	my ( $self, $c ) = @_;
	
	$c->stash->{template} = 'scoreboard.tt';
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
	
	$c->stash->{forbidden_msg} = $msg || 'Access denied';
	$c->stash->{template} = '403.tt';
	$c->res->status(403);
}

=head2 error

Error page

=cut

sub error :Private {
	my ( $self, $c, $msg ) = @_;
	
	$c->stash->{error} = $msg || 'Something went wrong';
	$c->stash->{template} = 'error.tt';
	$c->res->status(404);
}

=head2 tos

The Terms of Service page

=cut

sub tos :Local :Args(0) {
	my ( $self, $c) = @_;
	
	$c->stash->{template} = 'tos.tt';
}

=head2 render

Attempt to render a view, if needed.

=cut

sub render : ActionClass('RenderView') {}

sub end :Private {
	my ( $self, $c ) = @_;
	$c->forward('render');
}

=head1 AUTHOR

Cameron Thornton E<lt>cthor@cpan.orgE<gt>

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
