package WriteOff::Schema::ResultSet::ArtistAward;

use strict;
use base 'WriteOff::Schema::ResultSet';
use WriteOff::Award;

sub awards {
	return WriteOff::Award::sort_awards
	         map { WriteOff::Award->new($_) }
	           shift->get_column('award_id')->all;
}

1;
