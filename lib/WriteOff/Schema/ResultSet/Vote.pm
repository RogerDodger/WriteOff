package WriteOff::Schema::ResultSet::Vote;

use strict;
use base 'WriteOff::Schema::ResultSet';

sub mean {
	return shift->get_column('value')->func('avg');
}

sub average {
	return shift->mean;
}

sub stdev {
	return shift->get_column('value')->func('stdev');
}

sub ordered {
	return shift->search(
		{ value => { '!=' => undef }},
		{ order_by => { -desc => 'value' }}
	);
}

1;
