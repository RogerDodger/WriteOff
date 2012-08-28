package WriteOff::Controller::Root;
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller' }
with 'Catalyst::TraitFor::Controller::reCAPTCHA';

#
# Sets the actions in this controller to be registered with no prefix
# so they function identically to actions created in MyApp.pm
#
__PACKAGE__->config(namespace => '');

=head1 NAME

WriteOff::Controller::Root - Root Controller for WriteOff

=head1 METHODS

=cut

sub begin :Private {
	my ( $self, $c ) = @_;

	if( $c->req->method eq 'POST' ) {
		my $root = $c->uri_for('/');
		$c->detach('index') if $c->req->referer !~ /^$root/;
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
	
	$c->stash->{events} = [$c->model('DB::Event')->active_events];
	
    $c->stash->{template} = 'index.tt';
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
	
	$c->stash->{tempalte} = 'tos.tt';
}

=head2 end

Attempt to render a view, if needed.

=cut

sub end : ActionClass('RenderView') {}

=head1 AUTHOR

Cameron Thornton <cthor@cpan.org>

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
