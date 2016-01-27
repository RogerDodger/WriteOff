package WriteOff::Schema::ResultSet::Entry;

use strict;
use warnings;
use base 'WriteOff::Schema::ResultSet';

sub recalc_rank {
	my $self = shift;

	my @items = $self->order_by_score->all;
	my $n = $#items;

	for my $i (0..$n) {
		my $item = $items[$i];
		my ($rank, $rank_low) = ($i, $i);

		$rank-- while $rank > 0 && $item == $items[$rank-1];
		$rank_low++ while $rank_low < $n && $item == $items[$rank_low+1];

		$item->update({
			rank     => $rank,
			rank_low => $rank_low,
		});
	}
}

sub eligible {
	shift->search({ disqualified => 0 });
}

sub disqualified {
	shift->search({ disqualified => 1 });
}

sub rank_order {
	return shift->order_by({ -asc => [qw/rank title/] });
}

sub seed_order {
	return shift->order_by({ -desc => 'seed' });
}

1;
