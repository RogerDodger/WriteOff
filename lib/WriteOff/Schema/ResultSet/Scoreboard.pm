package WriteOff::Schema::ResultSet::Scoreboard;

use strict;
use base 'WriteOff::Schema::ResultSet';

my @medals = qw/gold silver bronze/;

sub medal_for {
	my($self, $pos) = @_;
	
	return $medals[$pos] if $pos <= $#medals;
	
	return wantarray ? () : undef;
}

sub with_pos {
	my $self = shift;
	
	my $pos = $self->search(
		{ 'other.score' => { '>' => { -ident => 'me.score' } } },
		{
			select => [{ '1 + count' => 'other.score' }],
			alias => 'other',
		}
	);
	
	return $self->search_rs(undef, {
		'+select' => [ { '' => $pos->as_query, -as => 'pos' } ],
		'+as'     => [ 'pos' ],
	});
}

sub tally {
	my( $self, $rs ) = @_;
	
	my @items = $rs->with_scores->with_stats;
	my $n = $#items;
	my %tally;
	
	my $max_stdev = $items[0];
	
	for my $this ( @items ) {
		my $store = $self->find_or_create({ competitor => $this->artist });
		my $artist = $store->competitor;
		
		$tally{$artist} //= { 
			score => $store->score, 
			awards => [],
		};
		
		$tally{$artist}{score} += $n - ($this->pos + $this->pos_low);
		
		push $tally{$artist}{awards}, $self->medal_for( $this->pos );	
		push $tally{$artist}{awards}, 'spoon' if $this->pos == $n;
		
		$max_stdev = $this if $this->stdev > $max_stdev->stdev;
	}
	
	while( my($artist, $new) = each %tally ) {
		my $store = $self->find($artist);
		
		push $new->{awards}, 'confetti' if lc $artist eq lc $max_stdev->artist;
		push $new->{awards}, 'ribbon'   if $new->{awards} ~~ [];
		
		$store->update({ score => $new->{score} > 0 ? $new->{score} : 0 });
		$store->add_awards( $new->{awards} );
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
