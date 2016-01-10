package WriteOff::Schema::ResultSet::Award;

use strict;
use warnings;
use base 'WriteOff::Schema::ResultSet';

sub unique {
	shift->search({}, { group_by => 'award_id' })->all;
}

1;
