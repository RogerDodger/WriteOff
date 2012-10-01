package WriteOff::Schema::ResultSet::Scoreboard;

use strict;
use base 'WriteOff::Schema::ResultSet';

my @medals = qw/gold silver bronze/;

sub tally {
	my( $self, $rs ) = @_;
	
	my @items = $rs->order_by_score;
	my $n = $#items;
	my %tally; 
	
	my $most_controversial = ($rs->order_by_stdev)[0];
	
	for my $item ( @items ) {
		my $store = $self->find_or_create({ competitor => $item->artist });
		my $artist = $store->competitor;
		
		my $lower = $item->pos_in( \@items );
		my $upper = $item->pos_in( \@items, 1);
		
		$tally{$artist} //= { score => $store->score };
		$tally{$artist}{score} += $n - ($upper + $lower);
		
		if( $lower <= $#medals ) {
			$tally{$artist}{awards} //= [];
			push $tally{$artist}{awards}, $medals[$lower];
		}
		
		if( $lower == $n ) {
			$tally{$artist}{awards} //= [];			
			push $tally{$artist}{awards}, 'spoon';
		}
		
		if( $most_controversial->id == $item->id ) {
			$tally{$artist}{awards} //= [];			
			push $tally{$artist}{awards}, 'confetti';
		}
	}
	
	while( my($artist, $new) = each %tally ) {
		my $store = $self->find($artist);
		$store->update({ score  => $new->{score} > 0 ? $new->{score} : 0 });
		$store->add_awards( $new->{awards} // ['ribbon'] );
	}
}

sub ordered {
	return shift->order_by([
		{ -desc => 'score' },
		{ -asc  => 'competitor' },
	]);
}

1;

__END__

=pod

=head1 NAME

WriteOff::Schema::ResultSet::Scoreboard - Application scoreboard.

=head1 SYNOPSIS

=head2 Scores

Both tally methods tally scores by the formula `n - 2p + 1`, where `n` is the
number of items in the tally and `p` is the position of the item.

(The actual equation used is `n - 2i - 1`, where `i` is the index of the item.
The two are equivalent since `p = i + 1`, so `n - 2p + 1 = n - 2(i + 1) + 1 =
n - 2i - 1`.)

Items with tied sort rank are given a position equal to the average of their
indices, e.g., if three items are tied for 2nd place, they will each get a score
where `p = avg(1, 2, 3) = 2`. This maintains the system as zero-sum.

=head2 Awards

Positions 1, 2, and 3 get gold, silver, and bronze medals respectively. In the
case of ties, the award given is that which goes to the highest position in the 
tied group (i.e., five items all tied for 3rd will each get a bronze medal).

All items with no other award are given a participation ribbon. If a competitor
appears more than once in a given set, they are only given one ribbon.

=head1 METHODS

=head2 tally

Tallies scores from either a L<WriteOff::Schema::ResultSet::Story> resultset or
a L<WriteOff::Schema::ResultSet::Image> resultset.

=cut
