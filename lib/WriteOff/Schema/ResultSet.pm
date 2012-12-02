package WriteOff::Schema::ResultSet;

use strict;
use base 'DBIx::Class::ResultSet';

sub datetime_parser {
	return shift->result_source->schema->storage->datetime_parser;
}

sub format_datetime {
	return shift->datetime_parser->format_datetime(shift);
}

sub parse_datetime {
	return shift->datetime_parser->parse_datetime(shift);
}

sub now {	
	my $self = shift;
	return $self->format_datetime( $self->now_dt );
}

sub now_dt {
	return DateTime->now;
	
	return shift->parse_datetime('2012-12-03 02:00:00');
}

sub created_before {
    my ($self, $datetime) = @_;

    my $date_str = $self->format_datetime($datetime);

    return $self->search_rs({ created => { '<' => $date_str } });
}

sub created_after {
    my ($self, $datetime) = @_;

    my $date_str = $self->format_datetime($datetime);

    return $self->search_rs({ created => { '>' => $date_str } });
}

sub seed_order {
	return shift->search_rs(undef, { order_by => { -desc => 'seed' } } );
}

sub order_by {
	my $self = shift;
	
	return $self->search_rs(undef, { order_by => shift });
}

=head2 with_stats

Returns a list with position and stdev columns set for row objects made by 
L<WriteOff::Schema::ResultSet::Image> or L<WriteOff::Schema::ResultSet::Story>
resultsets. Must be called after with_scores().

=cut

sub with_stats {
	my $self = shift;
	
	my @items = $self->all;
	my $n = $#items;
	
	for( my $i = 0; $i <= $n; $i++ ) {
		my $this = $items[$i];
		my ($pos, $pos_low) = ($i, $i);
		
		$pos-- while $pos > 0 && $this == $items[$pos-1];
		$this->{__pos} = $pos;
		
		$pos_low++ while $pos_low < $n && $this == $items[$pos_low+1];
		$this->{__pos_low} = $pos_low;
		
		my (@votes, $sum) = $this->votes->public->get_column('value')->all;
		
		if( @votes ) {
			$sum += ($_ - $this->public_score) ** 2 for @votes;
			$this->{__stdev} = sqrt $sum / @votes;
		}
		else {
			$this->{__stdev} = 0;
		}
	}
	
	return @items;
}

1;