package WriteOff::Schema::ResultSet::FormatRound;

use strict;
use warnings;
use base 'WriteOff::Schema::ResultSet';

sub ordered {
	shift->order_by({ -asc => 'offset' });
}

1;
