package WriteOff::Schema::ResultSet::Artist;

use strict;
use base 'WriteOff::Schema::ResultSet';

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

sub deal_awards_and_scores {
	my( $self, $rs ) = @_;
	my $awards = $self->result_source->schema->resultset('Award');
	
	my @items = $rs->with_scores->with_stats;
	my $n = $#items;
	
	my $max_stdev = $items[0];
	for my $item ( @items ) {
		$max_stdev = $item if $item->stdev > $max_stdev->stdev;
	}
	
	for my $item ( @items ) {
		my $artist = $self->find_or_create({ name => $item->artist });
		
		$artist->update({ user_id => $item->user_id }) 
			if !defined $artist->user_id;
		
		my %event_id_and_type = (
			event_id => $item->event_id,
			type     => $item->type,
		);
		
		$item->create_related('scores', {
			%event_id_and_type, 
			artist_id => $artist->id,
			value     => $n - ($item->pos + $item->pos_low),
		});
		
		my @awards = (
			$awards->medal_for($item->pos) // (),
			$max_stdev->id == $item->id ? $awards->find({ name => 'confetti' }) : (),
			$item->pos == $n ? $awards->find({ name => 'spoon' }) : (),
		);
		
		$artist->add_to_awards( $_, \%event_id_and_type ) for @awards;
	}
	
	#Give ribbons to anyone who didn't get an award
	my $ribbon = $awards->find({ name => 'ribbon' });
	for my $item ( @items ) {
		my $artist = $self->find({ name => $item->artist });
		
		my %event_id_and_type = (
			event_id => $item->event_id,
			type     => $item->type,
		);
		
		$artist->add_to_awards( $ribbon, \%event_id_and_type )
			if $artist->awards->search(\%event_id_and_type) == 0;
	}
}

sub recalculate_scores {
	my $self = shift;
	
	while( my $artist = $self->next ) {
		my $total = 0;
		
		my @scores = $artist->scores->search(undef, 
			{ 
				prefetch => 'event',
				order_by => 'end' 
			}
		);
		
		my $prev;
		for my $score ( @scores ) {
			$total = 0 if $total < 0 && $prev->event_id != $score->event_id;
			$total += $score->value;
			$prev = $score;
		}
		
		$artist->update({ score => $total < 0 ? 0 : $total });
	}
}

sub tallied {
	my $self = shift;
	
	my $rank_rs = $self->search(
		{
			score => { '>' => { -ident => 'me.score' } }
		},
		{
			'select' => [ \'COUNT(*) + 1' ],
			'alias' => 'subq',
		}
	);

	return $self->search(undef, {
		'+select' => [ $rank_rs->as_query ],
		'+as' => [ 'rank' ],
		order_by => [
			{ -desc => 'score' },
			{ -asc  => 'name'  },
		]
	})->all;
}

1;

__END__

=pod

=head1 NAME

WriteOff::Schema::ResultSet::Artist - Site's artists.

=head1 METHODS

=head2 tally

Tallies scores from either a L<WriteOff::Schema::ResultSet::Story> resultset or
a L<WriteOff::Schema::ResultSet::Image> resultset by the formula `n - 2p + 1`, 
where `n` is the number of items in the tally and `p` is the position of the 
item.

Items with tied sort rank are given a position equal to the average of their
indices, e.g., if three items are tied for 2nd place, they will each get a score
where `p = avg(1, 2, 3) = 2`. This maintains the system as zero-sum.

=head2 Awards

Positions 1, 2, and 3 get gold, silver, and bronze medals respectively. In the
case of ties, everyone gets the most valuable medal possible (i.e., five items 
all tied for 3rd will each get a bronze medal).

The item with the highest standard deviation in the public voting is awarded
confetti for being the 'Most Controversial'.

The item that comes dead last with no tie is awarded a wooden spoon.

All items with no other award are given a participation ribbon. If an artist
appears more than once in a given set, they are only given one ribbon.

=cut
