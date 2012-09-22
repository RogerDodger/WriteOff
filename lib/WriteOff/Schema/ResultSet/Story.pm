package WriteOff::Schema::ResultSet::Story;

use strict;
use base 'WriteOff::Schema::ResultSet';

sub tally_order {
	my $self = shift;

	return sort { 
		$b->private_score <=> $a->private_score ||
		$b->public_score  <=> $a->public_score  ||
		$a->title cmp $b->title 
	} $self->all
}

1;