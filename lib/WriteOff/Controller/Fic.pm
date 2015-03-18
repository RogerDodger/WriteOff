package WriteOff::Controller::Fic;
use Moose;
use namespace::autoclean;
use WriteOff::Util 'wordcount';
use Scalar::Util qw/looks_like_number/;

BEGIN { extends 'Catalyst::Controller' }

__PACKAGE__->config(model => 'Story');

sub _fetch :ActionClass('~Fetch') {}

sub fetch :Chained('/') :PathPart('fic') :CaptureArgs(1) {
	my ($self, $c) = @_;
	$c->forward('_fetch');
	$c->stash->{event} = $c->stash->{story}->event;
	unshift $c->stash->{title}, $c->stash->{event}->title;
}

sub view :Chained('fetch') :PathPart('') :Args(0) {
	my ( $self, $c ) = @_;

	if ($c->stash->{format} eq 'txt') {
		$c->res->content_type('text/plain; charset=utf-8');
		$c->res->body( $c->stash->{story}->contents );
	}
	elsif ($c->stash->{format} eq 'epub') {
		$c->forward('View::Epub');
	}
	else {
		$c->stash->{gallery} = [
			$c->stash->{event}->storys->gallery($c->user->offset)->all
		];
		$c->stash->{template} = 'fic/view.tt';
	}
}

sub gallery :Chained('/event/fic') :PathPart('gallery') :Args(0) {
	my ( $self, $c ) = @_;

	if ($c->stash->{format} eq 'epub') {
		$c->forward('View::Epub');
	}
	else {
		my $storys = $c->stash->{event}->storys->gallery($c->user->offset);

		$c->stash->{candidates} = $storys->candidates;
		$c->stash->{noncandidates} = $storys->noncandidates;

		push $c->stash->{title}, 'Gallery';
		$c->stash->{template} = 'fic/gallery.tt';
	}
}

sub form :Private {
	my ( $self, $c ) = @_;

	$c->forward('/check_csrf_token');

	$c->req->params->{wordcount} = wordcount( $c->req->params->{story} );

	# When editing, must allow for the title to be itself
	my $title_rs = $c->stash->{event}->storys->search({
		title => {
			'!=' => eval { $c->stash->{story}->title } || undef
		}
	});

	my $artist_rs = $c->model('DB::Artist')->search({
		name    => { '!=' => 'Anonymous' },
		# Must allow organisers to edit properly
		user_id => { '!=' => eval { $c->stash->{story}->user_id } || $c->user_id }
	});

	if ($c->stash->{event}->art) {
		my @ids = $c->stash->{event}->images->get_column('id')->all;
		my @params = $c->req->param('image_id') or return 0;

		my %uniq;
		for my $id (@params) {
			# Param must be in the set ot valid image_ids
			return 0 unless looks_like_number($id) && grep { $id == $_ } @ids;

			# Param must be unique
			return 0 if $uniq{$_};
			$uniq{$_} = 1;
		}
	}

	$c->form(
		title => [
			[ 'LENGTH', 1, $c->config->{len}{max}{title} ],
			'TRIM_COLLAPSE',
			'NOT_BLANK',
			[ 'DBIC_UNIQUE', $title_rs, 'title' ],
		],
		author => [
			[ 'LENGTH', 1, $c->config->{len}{max}{user} ],
			'TRIM_COLLAPSE',
			[ 'DBIC_UNIQUE', $artist_rs, 'name' ],
		],
		image_id => [ $c->stash->{event}->art ? 'NOT_BLANK' : () ],
		website => [ 'HTTP_URL' ],
		story => [ 'NOT_BLANK' ],
		wordcount => [
			[ 'BETWEEN', $c->stash->{event}->wc_min, $c->stash->{event}->wc_max ]
		],
	);

	1;
}

sub submit :Chained('/event/fic') :PathPart('submit') :Args(0) {
	my ( $self, $c ) = @_;

	push $c->stash->{title}, 'Submit';
	$c->stash->{template} = 'fic/submit.tt';

	$c->stash->{fillform}{author} = eval { $c->user->last_author
	                                    || $c->user->last_artist
	                                    || $c->user->name };

	$c->forward('do_submit')
		if $c->req->method eq 'POST'
		&& $c->user
		&& $c->stash->{event}->fic_subs_allowed;
}

sub do_submit :Private {
	my ( $self, $c ) = @_;

	$c->forward('form') or $c->detach('/error', [ 'Bad input' ]);

	if (!$c->form->has_error) {
		my $author = length $c->form->valid('author')
			? $c->form->valid('author')
			: 'Anonymous';

		my $artist = $c->model('DB::Artist')->find({ name => $author })
			// $c->user->create_related(artists => { name => $author });

		my $story = $c->model('DB::Story')->create({
			event_id  => $c->stash->{event}->id,
			user_id   => $c->user->id,
			artist_id => $artist->id,
			ip        => $c->req->address,
			title     => $c->form->valid('title'),
			website   => $c->form->valid('website') || undef,
			contents  => $c->form->valid('story'),
			wordcount => $c->form->valid('wordcount'),
			seed      => rand,
		});

		if ($c->stash->{event}->art) {
			for my $id ($c->req->param('image_id')) {
				my $image = $c->model('DB::Image')->find($id);
				$story->add_to_images($image);
			}
		}

		$c->flash->{status_msg} = 'Submission successful';
		$c->res->redirect( $c->req->referer || $c->uri_for('/') );
	}
}

sub edit :Chained('fetch') :PathPart('edit') :Args(0) {
	my ( $self, $c ) = @_;

	$c->detach('/forbidden', [ 'You cannot edit this item.' ])
		unless $c->stash->{story}->is_manipulable_by( $c->user );

	$c->forward('do_edit') if $c->req->method eq 'POST';

	$c->stash->{fillform} = {
		author   => $c->stash->{story}->artist->name,
		title    => $c->stash->{story}->title,
		image_id => [ $c->stash->{story}->images->get_column('id')->all ],
		website  => $c->stash->{story}->website,
		story    => $c->stash->{story}->contents,
	};

	push $c->stash->{title}, 'Edit';
	$c->stash->{template} = 'fic/edit.tt';
}

sub do_edit :Private {
	my ( $self, $c ) = @_;

	$c->forward( $self->action_for('form') ) or return 0;

	if (!$c->form->has_error) {
		my $story = $c->stash->{story};

		$c->log->info( sprintf "Fic %d edited by %s, to %s by %s (%d words)",
			$story->id,
			$c->user->get('username'),
			$c->form->valid('title'),
			$c->form->valid('author'),
			$c->form->valid('wordcount'),
		);

		my $author = length $c->form->valid('author')
			? $c->form->valid('author')
			: 'Anonymous';

		my $artist = $c->model('DB::Artist')->find({ name => $author })
			// $story->user->create_related(artists => { name => $author });

		$c->stash->{story}->update({
			title     => $c->form->valid('title'),
			artist_id => $artist->id,
			website   => $c->form->valid('website') || undef,
			contents  => $c->form->valid('story'),
			wordcount => $c->form->valid('wordcount'),
		});

		if ($c->stash->{event}->art) {
			$c->stash->{story}->image_stories->delete;
			for my $id ($c->req->param('image_id')) {
				my $image = $c->model('DB::Image')->find($id);
				$c->stash->{story}->add_to_images($image);
			}
		}


		$c->stash->{status_msg} = 'Edit successful';
	}

}

sub delete :Chained('fetch') :PathPart('delete') :Args(0) {
	my ( $self, $c ) = @_;

	$c->detach('/forbidden', ['You cannot delete this item.']) unless
		$c->stash->{story}->is_manipulable_by( $c->user );

	$c->stash->{key} = {
		name  => 'title',
		value => $c->stash->{story}->title,
	};

	$c->forward('do_delete') if $c->req->method eq 'POST';

	push $c->stash->{title}, 'Delete';
	$c->stash->{template} = 'item/delete.tt';
}

sub do_delete :Private {
	my ( $self, $c ) = @_;

	$c->forward('/check_csrf_token');

	$c->log->info( sprintf "Fic deleted by %s: %s (%s - %s)",
		$c->user->get('username'),
		$c->stash->{story}->title,
		$c->stash->{story}->ip,
		$c->stash->{story}->user->username,
	);

	$c->stash->{story}->delete;

	$c->flash->{status_msg} = 'Deletion successful';
	$c->res->redirect( $c->req->param('referer') || $c->uri_for('/') );
}

sub rels :Chained('fetch') :PathPart('rels') :Args(0) {
	my ( $self, $c ) = @_;

	$c->detach('/default') if !$c->stash->{story}->event->fic_gallery_opened;

	$c->stash->{items} = $c->stash->{story}->images->metadata;

	push $c->stash->{title}, 'Related Artwork(s)';
	$c->stash->{template} = 'item/list.tt';
}

=head1 AUTHOR

Cameron Thornton E<lt>cthor@cpan.orgE<gt>

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
