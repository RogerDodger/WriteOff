package WriteOff::Schema::ResultSet::Award;

use strict;
use base 'WriteOff::Schema::ResultSet';

sub ordered {
	return shift->order_by( 'sort_rank' );
}

1;
