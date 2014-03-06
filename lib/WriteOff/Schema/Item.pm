package WriteOff::Schema::Item;

# This package is Schema::Item and not Schema::ResultSet::Item because
# DBIx::Class::Schema::load_namespaces sends warnings when it detects a
# resultset with no associated result.

use strict;
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

sub recalc_public_stats {
	my $self = shift;

	for my $item ($self->all) {
		my $votes = $item->votes->public;

		$item->update({
			public_score => $votes->mean,
			public_stdev => $votes->stdev,
		});
	}

	return $self;
}

sub seed_order {
	return shift->search_rs(undef, { order_by => { -desc => 'seed' } } );
}

1;
