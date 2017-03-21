package WriteOff::Controller::Art;
use Moose;
use namespace::autoclean;
use Try::Tiny;

no warnings 'uninitialized';

BEGIN { extends 'Catalyst::Controller'; }

__PACKAGE__->config(model => 'Image');

sub _fetch :ActionClass('~Fetch') {}

sub fetch :Chained('/') :PathPart('art') :CaptureArgs(1) {
	my ($self, $c) = @_;
	$c->forward('_fetch');
	$c->stash->{entry} = $c->stash->{image}->entry;
	$c->stash->{event} = $c->stash->{entry}->event;
	unshift @{ $c->stash->{title} }, $c->stash->{event}->title;
}

sub view :Chained('fetch') :PathPart('') :Args(0) {
	my ( $self, $c ) = @_;

	$c->res->redirect(
		$c->stash->{image}->path($c->stash->{format} eq 'thumb')
	);
}

sub view :Chained('fetch') :PathPart('') :Args(0) {
	my ( $self, $c ) = @_;

	if ($c->stash->{event}->art_gallery_opened) {
		my @gallery = $c->stash->{event}->images->gallery->all;
		my $i = 0;
		$i++ while $gallery[$i]->id != $c->stash->{entry}->id && $i < $#gallery;
		$c->stash->{num} = $gallery[$i]->num;
		$c->stash->{prev} = $gallery[$i-1];
		$c->stash->{next} = $gallery[$i-$#gallery];

		if ($c->stash->{event}->commenting) {
			$c->forward('/prepare_thread', [ $c->stash->{entry}->posts_rs ]);
		}
	}

	$c->stash->{template} = 'art/view.tt';
}

sub gallery :Chained('/event/art') :PathPart('gallery') :Args(0) {
	my ( $self, $c ) = @_;

	$c->stash->{show_storys} = $c->stash->{event}->fic_gallery_opened;
	$c->stash->{gallery} = $c->stash->{event}->images->gallery->search({}, { prefetch => 'image' });

	push @{ $c->stash->{title} }, 'Gallery';
	$c->stash->{template} = 'art/gallery.tt';
}

sub form :Private {
	my ($self, $c) = @_;

	$c->stash->{mode} = 'art';
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
		try {
			$c->stash->{image}->write($upload->tempname);
		} catch {
			$c->stash->{error_msg} = $_;
		}
	}
}

sub submit :Chained('/event/art') :PathPart('submit') :Args(0) {
	my ( $self, $c ) = @_;

	$c->forward('form');

	if ($c->user) {
		$c->stash->{entrys} = $c->user->organises($c->stash->{event})
			? $c->stash->{event}->images
			: $c->stash->{event}->images->search({ user_id => $c->user->id });

		if ($c->req->method eq 'POST' && $c->stash->{event}->art_subs_allowed) {
			$c->forward('do_submit');
		}
	}

	push @{ $c->stash->{title} }, 'Submit';
	$c->stash->{template} = 'art/submit.tt';
}

sub do_submit :Private {
	my( $self, $c ) = @_;

	$c->forward('do_form') or $c->detach('/error', [ 'Bad input' ]);

	if (!$c->form->has_error && $c->req->upload('image')) {
		my $image = $c->stash->{image} = $c->model('DB::Image')->new_result({
			hovertext => $c->form->valid('hovertext'),
			mimetype  => $c->form->valid('mimetype'),
			filesize  => $c->form->valid('filesize'),
			version   => 'temp',
		});

		# Choose a random ID until it works (i.e., until it's unique)
		my $maxid = 2 * ($c->model('DB::Image')->count + 1_000);
		while (!$image->in_storage) {
			$image->id(int rand $maxid);
			eval { $image->insert };
		}

		$c->forward('do_write');
		if (defined $c->stash->{error_msg}) {
			$image->delete and return;
		}
		else {
			$image->update;
		}

		$c->forward('/entry/do_submit');
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
	};

	push @{ $c->stash->{title} }, 'Edit';
	$c->stash->{template} = 'art/edit.tt';
}

sub do_edit :Private {
	my ( $self, $c ) = @_;

	$c->forward('do_form') or $c->detach('/error', [ 'Bad input' ]);

	if (!$c->form->has_error) {
		if ($c->req->upload('image')) {
			$c->stash->{image}->set_columns({
				mimetype => $c->form->valid('mimetype'),
				filesize => $c->form->valid('filesize'),
			});

			$c->forward('do_write');

			if (defined $c->stash->{error_msg}) {
				$c->stash->{image}->discard_changes;
				return;
			}
		}

		$c->stash->{image}->update({
			hovertext => $c->form->valid('hovertext'),
		});

		$c->forward('/entry/do_edit');

		$c->log->info("Art %d edited by %s: %s by %s (%.2fKB)",
			$c->stash->{image}->id,
			$c->user->name,
			$c->form->valid('title'),
			$c->stash->{entry}->artist->name,
			$c->form->valid('filesize') / 1024,
		);
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

sub dq :Chained('fetch') :PathPart('dq') {
	my ($self, $c) = @_;

	$c->forward('/entry/dq');
}

sub rels :Chained('fetch') :PathPart('rels') :Args(0) {
	my ( $self, $c ) = @_;

	$c->detach('/default') if !$c->stash->{entry}->event->fic_gallery_opened;

	$c->stash->{items} = $c->stash->{image}->storys;
	$c->stash->{view} = $c->controller('Fic')->action_for('view');

	push @{ $c->stash->{title} }, 'Related Story(s)';
	$c->stash->{template} = 'item/list.tt';
}

sub results :Chained('/event/art') :PathPart('results') :Args(0) {
	my ($self, $c) = @_;

	$c->stash->{entrys} = $c->stash->{event}->images->eligible;
	$c->stash->{mode} = 'art';
	$c->stash->{view} = $self->action_for('view');
	$c->stash->{breakdown} = $self->action_for('votes');

	$c->forward('/event/results');
}

sub votes :Chained('fetch') :PathPart('votes') :Args(1) {
	my ($self, $c, $round) = @_;

	$c->forward('/entry/votes', [ $round ]);
}

=head1 AUTHOR

Cameron Thornton E<lt>cthor@cpan.orgE<gt>

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
