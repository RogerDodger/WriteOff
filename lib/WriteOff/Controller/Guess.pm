package WriteOff::Controller::Guess;
use Moose;
use namespace::autoclean;
use Scalar::Util qw/looks_like_number/;

BEGIN { extends 'Catalyst::Controller'; }

sub fic :PathPart('guess') :Chained('/event/fic') :Args(0) {
	my ($self, $c) = @_;
	my $e = $c->stash->{event};

	if ($e->author_guessing_allowed) {
		my $artists_rs = $c->model('DB::Artist');

		$c->stash->{candidates} =
			$e->prelim_votes_allowed
				? $e->storys->metadata->seed_order
				: $e->storys->metadata->candidates;

		$c->stash->{artists} = [
			map { $_->artist }
				$c->stash->{candidates}->search({}, {
					group_by => 'artist_id',
					prefetch => 'artist',
					order_by => 'artist.name',
				})
		];

		$c->forward('do_guess') if $c->req->method eq 'POST';
	}

	$c->stash(
		open  => $e->fic_end,
		close => $e->end,
		heading => 'Author Guessing',
		votes_allowed  => $e->author_guessing_allowed,
		votes_received => $e->vote_records->guess->fic->count,
	);

	$c->forward('fillform');

	push $c->stash->{title}, 'Author Guessing';
	$c->stash->{template} = 'vote/guess.tt';
}

sub do_guess :Private {
	my ($self, $c) = @_;
	return unless $c->user;

	# 'fic', 'art', ...
	my $type = $c->action->name;

	my $record = $c->model('DB::VoteRecord')->find_or_create({
		event_id => $c->stash->{event}->id,
		user_id  => $c->user_id,
		round    => 'guess',
		type     => $type,
	});

	my $item_id_col = { art => 'image_id', fic => 'story_id' }->{$type};
	if (!defined $item_id_col) {
		$c->log->warn("Unrecognised vote type: $type");
		return;
	}

	my @artists = @{ $c->stash->{artists} };
	for my $item ($c->stash->{candidates}->all) {
		# Users cannot vote on their own entries
		next if $item->user_id == $c->user_id;

		my $aid = $c->req->param($item->id);
		next unless defined $aid;

		my $guess = $c->model('DB::Guess')->find_or_new({
			$item_id_col => $item->id,
			record_id    => $record->id,
		});

		if (looks_like_number($aid) && grep { $aid == $_->id } @artists) {
			$guess->artist_id(int $aid);
			$guess->insert;
		} elsif ($guess->in_storage) {
			$guess->delete;
		}
	}

	$c->stash->{status_msg} = 'Vote updated';
}

sub fillform :Private {
	my ($self, $c) = @_;
	return unless $c->user;

	my $record = $c->stash->{event}->vote_records->guess->find({
		user_id => $c->user_id,
		type    => $c->action->name,
	});

	if (defined $record) {
		$c->stash->{fillform} = {
			map { $_->item->id => $_->artist_id } $record->guesses->all,
		};
	}
}

__PACKAGE__->meta->make_immutable;

1;
