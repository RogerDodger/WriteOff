package WriteOff::Controller::Guess;
use Moose;
use namespace::autoclean;
use Scalar::Util qw/looks_like_number/;

BEGIN { extends 'Catalyst::Controller'; }

sub fic :PathPart('guess') :Chained('/event/fic') :Args(0) {
	my ($self, $c) = @_;
	my $e = $c->stash->{event};

	$c->stash(
		open => $e->rounds->fic->submit->first->end_leeway,
		close => $e->end,
	);

	if ($e->author_guessing_allowed) {
		$c->stash->{candidates} = $e->storys->search({ artist_public => 0 })->gallery;
		$c->stash->{artists} = [
			map { $_->artist }
				$c->stash->{candidates}->search({}, {
					group_by => 'artist_id',
					prefetch => 'artist',
					order_by => 'artist.name',
				})
		];

		if ($c->user) {
			$c->stash->{theory} = $c->model("DB::Theory")->find_or_create({
				event_id => $e->id,
				user_id => $c->user->id
			});

			$c->stash->{fillform} = {
				map { $_->entry_id => $_->artist_id } $c->stash->{theory}->guesses->all,
			};

			$c->forward('do_guess') if $c->req->method eq 'POST';
		}
	}

	push $c->stash->{title}, $c->string('authorGuessing');
	$c->stash->{template} = 'vote/guess.tt';
}

sub do_guess :Private {
	my ($self, $c) = @_;

	my @artists = @{ $c->stash->{artists} };
	for my $entry ($c->stash->{candidates}->all) {
		# Users cannot vote on their own entries
		next if $entry->user_id == $c->user_id;

		my $aid = $c->req->param($entry->id);
		next unless defined $aid;

		my $guess = $c->model('DB::Guess')->find_or_new({
			entry_id  => $entry->id,
			theory_id => $c->stash->{theory}->id,
		});

		if (looks_like_number($aid) && grep { $aid == $_->id } @artists) {
			$guess->artist_id(int $aid);
			$guess->update_or_insert;
		} elsif ($guess->in_storage) {
			$guess->delete;
		}
	}

	$c->stash->{status_msg} = 'Vote updated';
}

__PACKAGE__->meta->make_immutable;

1;
