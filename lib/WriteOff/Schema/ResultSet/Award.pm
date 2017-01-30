package WriteOff::Schema::ResultSet::Award;

use strict;
use warnings;
use base 'WriteOff::Schema::ResultSet';

sub headers {
	grep { $_->tallied } shift->unique;
}

sub unique {
	sort { $a->order <=> $b->order } shift->search({}, { group_by => 'award_id' })->all;
}


1;
