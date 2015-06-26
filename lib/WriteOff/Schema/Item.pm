package WriteOff::Schema::Item;

# This package is Schema::Item and not Schema::ResultSet::Item because
# DBIx::Class::Schema::load_namespaces sends warnings when it detects a
# resultset with no associated result.

use strict;
use warnings;
use base 'WriteOff::Schema::ResultSet';

sub recalc_public_stats {
	my $self = shift;

	my $votes = $self->result_source->schema->resultset('Vote');

	# Foo::Bar::Baz -> Baz
	my $class = (lc ref $self) =~ s/.*:://r;

	my $public_values = $votes->public->search(
		{
			"inn.${class}_id" => { '=' => { -ident => "${class}s.id" } },
			'record.filled' => 1,
		},
		{
			alias => 'inn',
			join => 'record',
		}
	)->get_column('value');

	$self->update({
		public_score => $public_values->func_rs('avg')->as_query,
		public_stdev => $public_values->func_rs('stdev')->as_query,
	});
}

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
