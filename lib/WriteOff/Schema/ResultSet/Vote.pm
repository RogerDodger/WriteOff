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

sub prelim {
	return shift->search_rs(
		{ 'record.round' => 'prelim' },
		{ join => 'record' }
	);
}

sub public {
	return shift->search_rs(
		{ 'record.round' => 'public' },
		{ join => 'record' }
	);
}

sub private {
	return shift->search_rs(
		{ 'record.round' => 'private' },
		{ join => 'record' }
	);
}

sub valid {
	return shift->search_rs(
		{ 'record.filled' => 1 },
		{ join => 'record' },
	);
}

sub ordered {
	return shift->search(
		{ value => { '!=' => undef }},
		{ order_by => { -desc => 'value' }}
	);
}

1;
