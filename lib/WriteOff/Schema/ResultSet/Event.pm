package WriteOff::Schema::ResultSet::Event;

use strict;
use base 'WriteOff::Schema::ResultSet';

sub active_events {	
	my $self = shift;
	return $self->search(
		{ end => { '>' => $self->now } },
		{ order_by => { -asc => 'start' } },
	);
}

sub old_events {
	my $self = shift;
	return $self->search(
		{ end => { '<' => $self->now } },
		{ order_by => { -asc => 'start' } },
	);
}

1;