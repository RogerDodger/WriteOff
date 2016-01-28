package WriteOff::Schema::ResultSet::Theory;

use strict;
use warnings;
use base 'WriteOff::Schema::ResultSet';

sub by {
	my ($self, $artist) = @_;

	$self->search({ artist_id => $artist });
}

sub by_rs {
	shift->by(@_);
}

1;
