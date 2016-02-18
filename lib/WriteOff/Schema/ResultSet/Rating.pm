package WriteOff::Schema::ResultSet::Rating;

use strict;
use warnings;
use base 'WriteOff::Schema::ResultSet';

sub ordered {
	shift->search_rs({}, {
		order_by => { -desc => 'round.end' },
		join => 'round',
	});
}

1;
