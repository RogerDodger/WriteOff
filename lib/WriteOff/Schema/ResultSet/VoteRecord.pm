package WriteOff::Schema::ResultSet::VoteRecord;

use strict;
use base 'WriteOff::Schema::ResultSet';

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

sub round {
	return shift->search_rs({ round => shift });
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
