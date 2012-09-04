package WriteOff::Schema::ResultSet::Event;

use strict;
use base 'WriteOff::Schema::ResultSet';

sub active_events {	
	my $self = shift;
	return $self->search({end => { '>' => $self->now } });
}

sub old_events {
	my $self = shift;
	return $self->search({end => { '<' => $self->now } });
}

1;