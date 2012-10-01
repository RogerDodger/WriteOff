package WriteOff::Schema::ResultSet::Story;

use strict;
use base 'WriteOff::Schema::ResultSet';

sub order_by_score {
	my $self = shift;

	return sort { 
		$b->private_score <=> $a->private_score ||
		$b->public_score  <=> $a->public_score  ||
		$a->title cmp $b->title 
	} $self->all
}

sub order_by_stdev {
	my $self = shift;
	
	return sort { $b->stdev <=> $a->stdev } $self->all;
}

1;