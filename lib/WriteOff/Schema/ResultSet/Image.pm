package WriteOff::Schema::ResultSet::Image;

use strict;
use base 'WriteOff::Schema::ResultSet';

#Placeholders
sub with_scores {
	return shift;
}

sub with_stats {
	return shift->all;
}

1;