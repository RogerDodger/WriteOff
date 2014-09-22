package WriteOff::Schema::ResultSet::Score;

use strict;
use base 'WriteOff::Schema::ResultSet';

sub decay {
	shift->update({ value => \q{value * 0.9} });
}

1;
