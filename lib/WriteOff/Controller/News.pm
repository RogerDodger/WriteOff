package WriteOff::Controller::News;
use Moose;
use namespace::autoclean;
use JSON;
use Scalar::Util qw/looks_like_number/;
use WriteOff::Mode qw/:all/;

BEGIN { extends 'Catalyst::Controller'; }

__PACKAGE__->config(model => 'News');

sub _fetch :ActionClass('~Fetch');

sub fetch :Chained('/') :PathPart('news') :CaptureArgs(1) {
	my ($self, $c) = @_;
	$c->forward('_fetch');

	push @{ $c->stash->{title} }, $c->stash->{news}->title;
}

sub submit :Local {
	my ($self, $c) = @_;

	$c->user or $c->detach('/forbidden', [ $c->{loginRequired} ]);

	$c->forward('do_add') if $c->req->method eq 'POST';

	$c->stash->{template} = 'news/submit.tt';
	push @{ $c->stash->{title} }, $c->string('newArtistTitle');
}

sub do_add :Private {
	my ($self, $c) = @_;

	$c->forward('/check_csrf_token');
}

sub edit :Chained('fetch') :PathPart('edit') :Args(0) {
	my ($self, $c) = @_;

	$c->detach('/forbidden') if $c->user->id != $c->stash->{artist}->user_id;

	$c->stash->{template} = 'news/edit.tt';
	push @{ $c->stash->{title} }, $c->string('edit');
}

sub view :Chained('fetch') :PathPart('') :Args(0) {
	my ($self, $c) = @_;

	$c->stash->{template} = 'news/view.tt';
}

=head1 AUTHOR

Cameron Thornton E<lt>cthor@cpan.orgE<gt>

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
