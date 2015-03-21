package WriteOff::Controller::News;
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller'; }

__PACKAGE__->config(fetch => 'article');

sub auto :Private {
	my ( $self, $c ) = @_;

	push $c->stash->{title}, 'News';
}

sub fetch :PathPart('news') :Chained('/') :CaptureArgs(1) :ActionClass('~Fetch') {}

sub view :Chained('fetch') :PathPart('') :Args(0) {
	my ( $self, $c ) = @_;

	$c->stash->{template} = 'news/view.tt';
}

sub add :Local :Args(0) {
	my ( $self, $c ) = @_;

	$c->forward('/assert_admin');
	$c->forward('do_add') if $c->req->method eq 'POST';

	$c->stash->{submit} = 'Add new article';

	push $c->stash->{title}, 'Add';
	$c->stash->{template} = 'news/add.tt';
}

sub do_add :Private {
	my ( $self, $c ) = @_;

	$c->forward('form');

	if (!$c->form->has_error) {
		my $article = $c->user->create_related('news', $c->stash->{row});

		$c->flash->{status_msg} = 'News article created';
		$c->res->redirect( $c->uri_for(
			$self->action_for('view'),
			[ $article->id_uri ]
		) );
	}
}

sub edit :Chained('fetch') :PathPart('edit') :Args(0) {
	my ( $self, $c ) = @_;

	$c->forward('/assert_admin');
	$c->forward('do_edit') if $c->req->method eq 'POST';

	$c->stash->{fillform} = {
		title => $c->stash->{article}->title,
		body  => $c->stash->{article}->body,
	};
	$c->stash->{submit} = 'Save changes';

	push $c->stash->{title}, 'Edit';
	$c->stash->{template} = 'news/edit.tt';
}

sub do_edit :Private {
	my ( $self, $c ) = @_;

	$c->forward('form');

	if (!$c->form->has_error) {
		$c->stash->{article}->update($c->stash->{row});

		$c->flash->{status_msg} = 'Edit successful';
		$c->res->redirect( $c->uri_for(
			$self->action_for('view'),
			[ $c->stash->{article}->id_uri ]
		) );
	}
}

sub form :Private {
	my ( $self, $c ) = @_;

	$c->forward('/check_csrf_token');

	$c->form(
		title => [ 'NOT_BLANK', [ 'LENGTH', 1, $c->config->{len}{max}{title} ] ],
		body  => [ 'NOT_BLANK' ],
	);

	if (!$c->form->has_error) {
		$c->stash->{row} = {
			title => $c->form->valid('title'),
			body  => $c->form->valid('body'),
		};
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
