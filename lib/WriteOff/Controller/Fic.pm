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
	$c->stash->{entry} = $c->stash->{story}->entry;
	$c->stash->{event} = $c->stash->{entry}->event;
	unshift $c->stash->{title}, $c->stash->{event}->title;
}

sub view :Chained('fetch') :PathPart('') :Args(0) {
	my ( $self, $c ) = @_;

	if ($c->stash->{format} eq 'txt') {
		$c->res->content_type('text/plain; charset=utf-8');
		$c->res->body(
			$c->stash->{story}->published
				? $c->stash->{story}->contents
				: $c->string('storyRedacted')
		);
	}
	elsif ($c->stash->{format} eq 'epub') {
		$c->forward('View::Epub');
	}
	else {
		my @gallery = $c->stash->{event}->storys->gallery->all;
		for my $i (0..$#gallery) {
			if ($gallery[$i]->id == $c->stash->{story}->entry->id) {
				$c->stash->{num} = $gallery[$i]->num;
				$c->stash->{prev} = $gallery[$i-1];
				$c->stash->{next} = $gallery[$i-$#gallery];
				last;
			}
		}
		$c->stash->{template} = 'fic/view.tt';
	}
}

sub gallery :Chained('/event/fic') :PathPart('gallery') :Args(0) {
	my ( $self, $c ) = @_;

	if ($c->stash->{format} eq 'epub') {
		$c->forward('View::Epub');
	}
	else {
		$c->stash->{gallery} = $c->stash->{event}->storys->gallery;

		push $c->stash->{title}, 'Gallery';
		$c->stash->{template} = 'fic/gallery.tt';
	}
}

sub form :Private {
	my ($self, $c) = @_;

	$c->stash->{rounds} = $c->stash->{event}->rounds->writing;
	$c->forward('/entry/form');
}

sub do_form :Private {
	my ( $self, $c ) = @_;

	$c->forward('/entry/do_form');

	$c->req->params->{wordcount} = wordcount( $c->req->params->{story} );

	if ($c->stash->{event}->has('art')) {
		my @ids = $c->stash->{event}->images->get_column('id')->all;
		my @params = $c->req->param('image_id') or return 0;

		my %uniq;
		for my $id (@params) {
			# Param must be in the set of valid image_ids
			return 0 unless looks_like_number($id) && grep { $id == $_ } @ids;

			# Param must be unique
			return 0 if $uniq{$_};
			$uniq{$_} = 1;
		}
	}

	$c->form(
		image_id => [ $c->stash->{event}->has('art') ? 'NOT_BLANK' : () ],
		story => [ 'NOT_BLANK' ],
		wordcount => [
			[ 'BETWEEN', $c->stash->{event}->wc_min, $c->stash->{event}->wc_max ]
		],
	);

	1;
}

sub submit :Chained('/event/fic') :PathPart('submit') :Args(0) {
	my ( $self, $c ) = @_;

	$c->forward('form');

	if ($c->user) {
		$c->stash->{entrys} = $c->stash->{event}->storys->search({ user_id => $c->user->id });

		if ($c->req->method eq 'POST') {
			if ($c->req->param('flip')) {
				$c->forward('flip');
			}
			elsif ($c->stash->{event}->fic_subs_allowed) {
				$c->forward('do_submit');
			}
		}
	}

	push $c->stash->{title}, 'Submit';
	$c->stash->{template} = 'fic/submit.tt';
}

sub do_submit :Private {
	my ( $self, $c ) = @_;

	$c->forward('do_form') or $c->detach('/error', [ 'Bad input' ]);
	$c->forward('/entry/do_submit');

	if (!$c->form->has_error) {
		my $story = $c->model('DB::Story')->new_result({
			contents  => $c->form->valid('story'),
			wordcount => $c->form->valid('wordcount'),
		});

		# Choose a random ID until it works (i.e., until it's unique)
		my $maxid = 2 * ($c->model('DB::Story')->count + 1_000);
		while (!$story->in_storage) {
			$story->id(int rand $maxid);
			eval { $story->insert };
		}

		$c->stash->{entry}->story_id($story->id);
		$c->stash->{entry}->insert;

		if ($c->stash->{event}->has('art')) {
			my $imgstry = $c->model('DB::ImageStory');
			for my $id ($c->req->param('image_id')) {
				$imgstry->create({
					story_id => $story->id,
					image_id => int $id,
				});
			}
		}

		$c->log->info("Fic %d submitted by %s: %s by %s (%d words)",
			$story->id,
			$c->user->name,
			$c->form->valid('title'),
			$c->model('DB::Artist')->find($c->form->valid('artist'))->name,
			$c->form->valid('wordcount'),
		);
	}
}

sub flip :Private {
	my ($self, $c) = @_;

	$c->forward('/check_csrf_token');

	my $allowUnpub = $c->stash->{event}->ended;

	while (my $entry = $c->stash->{entrys}->next) {
		my $story = $entry->story;
		my $id = $story->id;

		if ($allowUnpub) {
			my $val = !!$c->req->param("publish-$id");
			if ($story->published != $val) {
				$c->log->info("Fic %d %s SET published=%d", $story->id, $entry->title, $val);
				$story->update({ published => int $val });
			}
		}

		my $val = !!$c->req->param("index-$id");
		if ($story->indexed != $val) {
			$c->log->info("Fic %d %s SET indexed=%d", $story->id, $entry->title, $val);
			$story->update({ indexed => int $val });
		}
	}

	$c->res->redirect($c->req->uri) unless $c->stash->{ajax};
}

sub edit :Chained('fetch') :PathPart('edit') :Args(0) {
	my ( $self, $c ) = @_;

	$c->detach('/forbidden', [ $c->string('cantEdit') ])
		if !$c->user->can_edit($c->stash->{story});

	$c->forward('form');
	if ($c->req->method eq 'POST' && $c->stash->{event}->fic_subs_allowed) {
		$c->forward('do_edit');
	}

	$c->stash->{fillform} = {
		artist   => $c->stash->{story}->entry->artist_id,
		title    => $c->stash->{story}->entry->title,
		image_id => [ $c->stash->{story}->images->get_column('id')->all ],
		story    => $c->stash->{story}->contents,
	};

	push $c->stash->{title}, 'Edit';
	$c->stash->{template} = 'fic/edit.tt';
}

sub do_edit :Private {
	my ( $self, $c ) = @_;

	$c->forward('do_form') or $c->detach('/error', [ 'Bad input' ]);
	$c->forward('/entry/do_edit');

	if (!$c->form->has_error) {
		$c->log->info("Fic %d edited by %s to %s by %s (%d words)",
			$c->stash->{story}->id,
			$c->user->name,
			$c->form->valid('title'),
			$c->model('DB::Artist')->find($c->form->valid('artist'))->name,
			$c->form->valid('wordcount'),
		);

		$c->stash->{story}->update({
			contents  => $c->form->valid('story'),
			wordcount => $c->form->valid('wordcount'),
		});

		if ($c->stash->{event}->has('art')) {
			$c->stash->{story}->image_stories->delete;
			my $imgstry = $c->model('DB::ImageStory');
			for my $id ($c->req->param('image_id')) {
				my $image = $c->model('DB::Image')->find($id);
				$c->stash->{story}->add_to_images($image);
			}
		}
	}
}

sub delete :Chained('fetch') :PathPart('delete') :Args(0) {
	my ( $self, $c ) = @_;

	$c->forward('/entry/delete');
}

sub do_delete :Private {
	my ( $self, $c ) = @_;

	$c->forward('/entry/do_delete');
}

sub rels :Chained('fetch') :PathPart('rels') :Args(0) {
	my ( $self, $c ) = @_;

	$c->detach('/default') if !$c->stash->{story}->event->fic_gallery_opened;

	$c->stash->{items} = $c->stash->{story}->images->metadata;

	push $c->stash->{title}, 'Related Artwork(s)';
	$c->stash->{template} = 'item/list.tt';
}

sub results :Chained('/event/fic') :PathPart('results') :Args(0) {
	my ($self, $c) = @_;

	$c->stash->{items} = $c->stash->{event}->storys->eligible;

	$c->stash->{guesses} = $c->stash->{event}->theorys->search(
		{
			accuracy => { '>=' => 3 },
		},
		{
			prefetch => [
				'artist',
				{ guesses => 'entry' },
			],
			order_by => [
				{ -desc => 'me.accuracy' },
				{ -asc => 'artist.name' },
			],
		}
	);

	$c->stash->{mode} = 'fic';
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
