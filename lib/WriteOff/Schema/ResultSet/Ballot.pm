package WriteOff::Schema::ResultSet::Ballot;

use strict;
use base 'WriteOff::Schema::ResultSet';
use WriteOff::Award qw/:awards/;

sub filled {
	my $self = shift;

	return $self->search({ filled => 1 });
}

sub unfilled {
	return shift->search_rs({ filled => 0 });
}

sub ordered {
	return shift->order_by([
		{ -asc => 'type' },
		{ -asc => 'updated' },
	]);
}

sub recalc_stats {
	my $self = shift;

	while (my $row = $self->next) {
		my $votes = $row->votes;

		$row->update({
			mean  => $votes->mean,
			stdev => $votes->stdev,
		});
	}
}

sub judge_records {
	return shift->search_rs({
		round => 'private',
	}, {
		prefetch => 'user',
		order_by => { -asc => 'user.username ' },
	});
}

sub process_guesses {
	my $self = shift;
	my $best = 0;

	while (my $row = $self->next) {
		my $correct = 0;
		for my $guess ($row->guesses) {
			$correct += $guess->artist_id == $guess->item->artist_id;
		}

		$row->update({
			artist_id => $row->user->primary_artist->id,
			score     => $correct,
		});

		$best = $correct if $correct > $best;
	}

	my $row = $self->first;
	my %aa_row = (
		event_id => $row->event_id,
		type     => $row->type,
		award_id => SLEUTH()->id,
	);

	while (my $row = $self->next) {
		next unless $row->score == $best;

		$row->artist->create_related('artist_awards', \%aa_row);
	}
}

sub slates {
	my $self = shift;
	my @slates;
	while (my $record = $self->next) {
		push @slates, [map { $_->story_id } $record->votes->ordered->all];
	}
	return \@slates;
}

sub round {
	return shift->search_rs({ round => shift });
}

sub guess {
	return shift->round('guess');
}

sub prelim {
	return shift->round('prelim');
}

sub public {
	return shift->round('public');
}

sub private {
	return shift->round('private');
}

sub type {
	return shift->search_rs({ type => shift })
}

sub fic {
	return shift->type('fic');
}

sub art {
	return shift->type('art');
}

1;
