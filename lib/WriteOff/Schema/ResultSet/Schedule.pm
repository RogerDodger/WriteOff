package WriteOff::Schema::ResultSet::Schedule;

use strict;
use base 'WriteOff::Schema::ResultSet';

sub active_schedules {	
	my $self = shift;
	return $self->search({ at => { '<' => $self->now } });
}

1;