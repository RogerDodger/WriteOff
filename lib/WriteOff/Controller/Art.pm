package WriteOff::Controller::Art;
use Moose;
use namespace::autoclean;
require Image::Magick;

no warnings 'uninitialized';

BEGIN { extends 'Catalyst::Controller'; }

__PACKAGE__->config(model => 'Image');

sub _fetch :ActionClass('~Fetch') {}

sub fetch :Chained('/') :PathPart('art') :CaptureArgs(1) {
	my ($self, $c) = @_;
	$c->forward('_fetch');
	$c->stash->{entry} = $c->stash->{image}->entry;
	$c->stash->{event} = $c->stash->{entry}->event;
	unshift $c->stash->{title}, $c->stash->{event}->title;
}

sub view :Chained('fetch') :PathPart('') :Args(0) {
	my ( $self, $c ) = @_;

	$c->res->redirect(
		$c->stash->{image}->path($c->stash->{format} eq 'thumb')
	);
}

sub gallery :Chained('/event/art') :PathPart('gallery') :Args(0) {
	my ( $self, $c ) = @_;

	$c->stash->{show_artists} = $c->stash->{event}->is_ended;
	$c->stash->{show_storys} = $c->stash->{event}->fic_gallery_opened;

	$c->stash->{images} = $c->stash->{event}->images->seed_order;

	push $c->stash->{title}, 'Gallery';
	$c->stash->{template} = 'art/gallery.tt';
}

sub form :Private {
	my ($self, $c) = @_;

	$c->stash->{rounds} = $c->stash->{event}->rounds->art->submit;
	$c->forward('/entry/form');
}

sub do_form :Private {
	my ( $self, $c ) = @_;

	$c->forward('/entry/do_form');

	my $img = $c->req->upload('image');
	if ($img) {
		$c->req->params->{mimetype} = $img->mimetype;
		$c->req->params->{filesize} = $img->size;
	}

	$c->form(
		hovertext => [
			[ 'LENGTH', 1, $c->config->{len}{max}{alt} ],
			'TRIM_COLLAPSE',
		],
		mimetype  => [ [ 'IN_ARRAY', @{ $c->config->{biz}{img}{types} } ] ],
		filesize  => [ [ 'LESS_THAN', $c->config->{biz}{img}{size} ] ],
	);
}

sub do_write :Private {
	my ($self, $c) = @_;

	if (my $upload = $c->req->upload('image')) {
		my $err = $c->stash->{image}->write($upload->tempname);
		if ($err) {
			$c->log->error($err);
			$c->detach('/error', [ 'Image upload failed.' ]);
		}
	}
}

sub submit :Chained('/event/art') :PathPart('submit') :Args(0) {
	my ( $self, $c ) = @_;

	$c->forward('form');

	if ($c->user) {
		$c->stash->{entrys} = $c->stash->{event}->images->search({ user_id => $c->user->id });

		if ($c->stash->{event}->art_subs_allowed) {
			$c->forward('do_submit');
		}
	}

	push $c->stash->{title}, 'Submit';
	$c->stash->{template} = 'art/submit.tt';
}

sub do_submit :Private {
	my( $self, $c ) = @_;

	$c->forward('do_form') or $c->detach('/error', [ 'Bad input' ]);
	$c->forward('/entry/do_submit');

	if (!$c->form->has_error && $c->req->upload('image')) {
		my $image = $c->stash->{image} = $c->model('DB::Image')->new_result({
			hovertext => $c->form->valid('hovertext'),
			mimetype  => $c->form->valid('mimetype'),
			filesize  => $c->form->valid('filesize'),
		});

		# Choose a random ID until it works (i.e., until it's unique)
		my $maxid = 2 * ($c->model('DB::Image')->count + 1_000);
		while (!$image->in_storage) {
			$image->id(int rand $maxid);
			eval { $image->insert };
		}

		$c->forward('do_write');
		$image->update;

		$c->stash->{entry}->image_id($image->id);
		$c->stash->{entry}->insert;

		$c->log->info("Art %d submitted by %s: %s by %s (%.2fKB)",
			$image->id,
			$c->user->name,
			$c->form->valid('title'),
			$c->stash->{entry}->artist->name,
			$c->form->valid('filesize') / 1024,
		);
	}
}

sub edit :Chained('fetch') :PathPart('edit') :Args(0) {
	my ( $self, $c ) = @_;

	$c->detach('/forbidden', [ $c->string('cantEdit') ])
		if !$c->user->can_edit($c->stash->{image});

	$c->forward('form');
	if ($c->req->method eq 'POST' && $c->stash->{event}->art_subs_allowed) {
		$c->forward('do_edit');
	}

	$c->stash->{fillform} = {
		artist     => $c->stash->{image}->entry->artist_id,
		title      => $c->stash->{image}->entry->title,
		hovertext  => $c->stash->{image}->hovertext,
		website    => $c->stash->{image}->contents,
	};

	push $c->stash->{title}, 'Edit';
	$c->stash->{template} = 'art/edit.tt';
}

sub do_edit :Private {
	my ( $self, $c ) = @_;

	$c->forward('do_form') or $c->detach('/error', [ 'Bad input' ]);
	$c->forward('/entry/do_edit');

	if (!$c->form->has_error) {
		$c->log->info("Art %d edited by %s: %s by %s (%.2fKB)",
			$c->stash->{story}->id,
			$c->user->name,
			$c->form->valid('title'),
			$c->stash->{entry}->artist->name,
			$c->form->valid('filesize') / 1024,
		);

		$c->stash->{image}->update({
			hovertext => $c->form->valid('hovertext'),
		});

		if ($c->req->upload('image')) {
			$c->forward('do_write');

			$c->stash->{image}->update({
				mimetype => $c->form->valid('mimetype'),
				filesize => $c->form->valid('filesize'),
			});
		}
	}
}

sub delete :Chained('fetch') :PathPart('delete') :Args(0) {
	my ( $self, $c ) = @_;

	$c->forward('/entry/delete');
}

sub do_delete :Private {
	my ( $self, $c ) = @_;

	$c->forward('/check_csrf_token');
	$c->stash->{image}->version("")->clean;
	$c->forward('/entry/do_delete');
}

sub rels :Chained('fetch') :PathPart('rels') :Args(0) {
	my ( $self, $c ) = @_;

	$c->detach('/default') if !$c->stash->{image}->event->fic_gallery_opened;

	$c->stash->{items} = $c->stash->{image}->storys->metadata;

	push $c->stash->{title}, 'Related Story(s)';
	$c->stash->{template} = 'item/list.tt';
}

sub results :Chained('/event/art') :PathPart('results') :Args(0) {
	my ($self, $c) = @_;

	$c->stash->{entrys} = $c->stash->{event}->images->eligible;
	$c->stash->{mode} = 'art';
	$c->stash->{view} = $self->action_for('view');

	$c->forward('/event/results');
}

=head1 AUTHOR

Cameron Thornton E<lt>cthor@cpan.orgE<gt>

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
