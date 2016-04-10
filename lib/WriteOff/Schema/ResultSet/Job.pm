package WriteOff::Schema::ResultSet::Job;

use strict;
use base 'WriteOff::Schema::ResultSet';

sub active {
	my $self = shift;
	return $self->search({ at => { '<=' => $self->now } });
}

1;
