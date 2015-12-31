package WriteOff::Schema::ResultSet::Event;

use strict;
use base 'WriteOff::Schema::ResultSet';

sub active {
	my $self = shift;
	return $self->search({},
		{
			order_by => { -desc => 'created' },
			rows => 5,
		},
	);
}

sub old {
	my $self = shift;
	return $self->search({},
		{ order_by => { -desc => 'created' } },
	);
}

sub finished {
	my $self = shift;
	return $self->search(
		{ end => { '<' => $self->now } },
		{ order_by => { -asc => 'created' } }
	);
}

1;
