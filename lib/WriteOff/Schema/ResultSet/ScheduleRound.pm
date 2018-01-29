package WriteOff::Schema::ResultSet::ScheduleRound;

use strict;
use warnings;
use base 'WriteOff::Schema::ResultSet';

sub ordered {
	shift->order_by({ -asc => 'offset' });
}

1;
