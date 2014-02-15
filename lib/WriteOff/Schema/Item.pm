package WriteOff::Schema::Item;

# This package is Schema::Item and not Schema::ResultSet::Item because
# DBIx::Class::Schema::load_namespaces sends warnings when it detects a
# resultset with no associated result.

use strict;
use base 'WriteOff::Schema::ResultSet';

sub recalc_stats {
	my $self = shift;

	my @items = $self->all;
	my $n = $#items;

	for (my $i = 0; $i <= $n; $i++) {
		my $item = $items[$i];
		my ($pos, $pos_low) = ($i, $i);

		$pos-- while $pos > 0 && $item == $items[$pos-1];
		$pos_low++ while $pos_low < $n && $item == $items[$pos_low+1];

		my $votes = $item->votes;

		$item->update({
			rank     => $pos,
			rank_low => $pos_low,
			mean     => $votes->mean,
			stdev    => $votes->stdev,
		});
	}

	$self;
}

sub seed_order {
	return shift->search_rs(undef, { order_by => { -desc => 'seed' } } );
}

sub with_stats {
	my $self = shift;
	$self->recalc_stats;
	return $self;
}

1;
