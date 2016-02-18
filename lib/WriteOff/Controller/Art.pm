package WriteOff::Controller::Art;
use Moose;
use namespace::autoclean;
require Image::Magick;

no warnings 'uninitialized';

BEGIN { extends 'Catalyst::Controller'; }

__PACKAGE__->config(model => 'Image');

sub fetch :Chained('/') :PathPart('art') :CaptureArgs(1) :ActionClass('~Fetch') {}

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

sub submit :Chained('/event/art') :PathPart('submit') :Args(0) {
	my ( $self, $c ) = @_;

	$c->stash->{fillform}{artist} = eval { $c->user->last_artist
		                                || $c->user->last_author
		                                || $c->user->name };

	$c->forward('do_submit')
		if $c->req->method eq 'POST'
		&& $c->user
		&& $c->stash->{event}->art_subs_allowed;

	push $c->stash->{title}, 'Submit';
	$c->stash->{template} = 'art/submit.tt';
}

sub do_submit :Private {
	my( $self, $c ) = @_;

	$c->forward('form');

	if (!$c->form->has_error) {
		$c->stash->{row}{user_id} = $c->user_id;
		$c->stash->{row}{ip}      = $c->req->address;
		$c->stash->{row}{seed}    = rand;

		my $img = $c->stash->{event}->create_related(
			'images', $c->stash->{row}
		);
		my $err = $img->write($c->req->upload('image')->tempname);

		if (!$err) {
			$c->flash->{status_msg} = 'Submission successful';
			$c->res->redirect( $c->req->referer || $c->uri_for('/') );
		} else {
			$img->delete;
			$c->detach('/error', [ 'Image upload failed.' ]);
			$c->log->error($err);
		}
	}
}

sub edit :Chained('fetch') :PathPart('edit') :Args(0) {
	my ( $self, $c ) = @_;

	$c->detach('/forbidden', [ 'You cannot edit this item.' ])
		unless $c->stash->{image}->is_manipulable_by( $c->user );

	$c->forward('do_edit') if $c->req->method eq 'POST';

	$c->stash->{fillform} = {
		artist    => $c->stash->{image}->artist->name,
		title     => $c->stash->{image}->title,
		hovertext => $c->stash->{image}->hovertext,
		website   => $c->stash->{image}->website,
	};

	$c->stash->{preview} = $c->stash->{image}->path('thumb');

	push $c->stash->{title}, 'Edit';
	$c->stash->{template} = 'art/edit.tt';
}

sub do_edit :Private {
	my ( $self, $c ) = @_;

	$c->forward('form');

	if (!$c->form->has_error) {
		# Set this in memory so the file is written to the right filename. We
		# don't want to update the DB until the image has been written
		# successfully.
		$c->stash->{image}->title($c->stash->{row}{title});

		if (my $upload = $c->req->upload('image')) {
			my $err = $c->stash->{image}->write($upload->tempname);
			if ($err) {
				$c->detach('/error', [ 'Image upload failed.' ]);
				$c->log->error($err);
			}
		}

		$c->stash->{image}->update( $c->stash->{row} );

		$c->log->info( sprintf "Art %d edited by %s, to %s by %s (%.2fKB)",
			$c->stash->{image}->id,
			$c->user->name,
			$c->stash->{image}->title,
			$c->stash->{image}->artist->name,
			$c->stash->{image}->filesize / 1024,
		);

		$c->flash->{status_msg} = 'Edit successful';

		# Redirect in case the title changed
		$c->res->redirect(
			$c->uri_for( $c->action, [ $c->stash->{image}->id_uri ] )
		);
	}
}

sub form :Private {
	my ( $self, $c ) = @_;

	$c->stash->{event} ||= $c->stash->{image}->event;

	# When editing, must allow for the title to be itself
	my $title_rs = $c->stash->{event}->images->search({
		title => {
			'!=' => eval { $c->stash->{image}->title } || undef
		}
	});

	my $img = $c->req->upload('image');
	if ($img) {
		$c->req->params->{mimetype} = $img->mimetype;
		$c->req->params->{filesize} = $img->size;
	}

	my $virtual_artist_rs = $c->model('DB::Virtual::Artist')->search({
		name    => { '!=' => 'Anonymous' },
		# Must allow organisers to edit properly
		user_id => { '!=' => eval { $c->stash->{image}->user_id } || $c->user_id },
	});

	$c->form(
		title => [
			'NOT_BLANK',
			[ 'LENGTH', 1, $c->config->{len}{max}{title} ],
			'TRIM_COLLAPSE',
			[ 'DBIC_UNIQUE', $title_rs, 'title' ],
		],
		artist => [
			[ 'LENGTH', 1, $c->config->{len}{max}{user} ],
			'TRIM_COLLAPSE',
			[ 'DBIC_UNIQUE', $virtual_artist_rs, 'name' ]
		],
		hovertext => [
			[ 'LENGTH', 1, $c->config->{len}{max}{alt} ],
			'TRIM_COLLAPSE',
		],
		website   => [ 'HTTP_URL' ],
		mimetype  => [ [ 'IN_ARRAY', @{ $c->config->{biz}{img}{types} } ] ],
		filesize  => [ [ 'LESS_THAN', $c->config->{biz}{img}{size} ] ],
	);

	$c->stash->{row} = {
		title     => $c->form->valid('title'),
		artist    => $c->form->valid('artist') || 'Anonymous',
		hovertext => $c->form->valid('hovertext') || undef,
		website   => $c->form->valid('website') || undef,
	};

	if ($img) {
		$c->stash->{row}{filesize} = $c->form->valid('filesize');
		$c->stash->{row}{mimetype} = $c->form->valid('mimetype');
	}
}

sub delete :Chained('fetch') :PathPart('delete') :Args(0) {
	my ( $self, $c ) = @_;

	$c->detach('/forbidden', ['You cannot delete this item.']) unless
		$c->stash->{image}->is_manipulable_by( $c->user );

	$c->stash->{key} = {
		name  => 'title',
		value => $c->stash->{image}->title,
	};

	$c->forward('do_delete') if $c->req->method eq 'POST';

	push $c->stash->{title}, 'Delete';
	$c->stash->{template} = 'item/delete.tt';
}

sub do_delete :Private {
	my ( $self, $c ) = @_;

	$c->forward('/check_csrf_token');

	$c->log->info( sprintf "Art deleted by %s: %s (%s - %s)",
		$c->user->name,
		$c->stash->{image}->title,
		$c->stash->{image}->ip,
		$c->stash->{image}->user->username,
	);

	$c->stash->{image}->delete;

	$c->flash->{status_msg} = 'Deletion successful';
	$c->res->redirect( $c->req->param('referer') || $c->uri_for('/') );

}

sub rels :Chained('fetch') :PathPart('rels') :Args(0) {
	my ( $self, $c ) = @_;

	$c->detach('/default') if !$c->stash->{image}->event->fic_gallery_opened;

	$c->stash->{items} = $c->stash->{image}->stories->metadata;

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
