package WriteOff::Schema::ResultSet::Artist;

use strict;
use base 'WriteOff::Schema::ResultSet';
use WriteOff::Award qw/:all/;

sub active {
	shift->search({ active => 1 });
}

1;
