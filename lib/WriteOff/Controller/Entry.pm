package WriteOff::Controller::Entry;
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller' }

sub form :Private {
	my ($self, $c) = @_;

	$c->stash->{fillform}{artist} = $c->user->active_artist_id;

	if ($c->stash->{rounds}->active->count) {
		$c->stash->{countdown} = $c->stash->{rounds}->active->first->end;
	}
	elsif ($c->stash->{rounds}->upcoming->count) {
		$c->stash->{countdown} = $c->stash->{rounds}->upcoming->first->start;
	}

	if ($c->user) {
		$c->stash->{artists} = $c->model('DB::Artist')->search({
			-or => [
				{ user_id => $c->user->id },
				{ name => 'Anonymous' },
			],
		}, {
			order_by => [
				{ -desc => \q{name = 'Anonymous'} },
				{ -asc => 'created' },
			],
		});
	}
}

sub do_form :Private {
	my ($self, $c) = @_;

	$c->forward('/check_csrf_token');

	# When editing, must allow for the title to be itself
	my $titles = $c->stash->{event}->storys->search({
		title => {
			'!=' => eval { $c->stash->{entry}->title } || undef
		}
	});

	$c->form(
		title => [
			[ 'LENGTH', 1, $c->config->{len}{max}{title} ],
			'TRIM_COLLAPSE',
			'NOT_BLANK',
			[ 'DBIC_UNIQUE', $titles, 'title' ],
		],
		artist => [
			qw/NOT_BLANK INT/,
			['NOT_DBIC_UNIQUE', $c->stash->{artists}, 'id'],
		],
	);
}

sub do_submit :Private {
	my ($self, $c) = @_;

	if (!$c->form->has_error) {
		$c->stash->{entry} = $c->model('DB::Entry')->new_result({
			user_id   => $c->user->id,
			event_id  => $c->stash->{event}->id,
			artist_id => $c->form->valid('artist'),
			title     => $c->form->valid('title'),
		});

		$c->flash->{status_msg} = 'Submission successful';
		$c->res->redirect($c->req->uri);
	}
}

sub do_edit :Private {
	my ($self, $c) = @_;

	if (!$c->form->has_error) {
		$c->stash->{entry}->update({
			title     => $c->form->valid('title'),
			artist_id => $c->form->valid('artist'),
		});

		$c->flash->{status_msg} = 'Edit successful';
		$c->res->redirect($c->req->uri);
	}
}

__PACKAGE__->meta->make_immutable;

1;
