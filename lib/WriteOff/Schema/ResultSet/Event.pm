package WriteOff::Schema::ResultSet::Event;

use strict;
use base 'WriteOff::Schema::ResultSet';

sub active {	
	my $self = shift;
	return $self->search(
		{ end =>
			{ '>' =>
				$self->format_datetime( $self->now_dt->subtract( days => 1 ) )
			}
		},
		{ order_by => { -asc => 'end' } },
	);
}

sub old {
	my $self = shift;
	return $self->search(
		{ end =>
			{ '<' =>
				$self->format_datetime( $self->now_dt->subtract( days => 1 ) )
			}
		},
		{ order_by => { -desc => 'end' } },
	);
}

sub finished {
	my $self = shift;
	return $self->search(
		{ end => { '<' => $self->now } },
		{ order_by => { -asc => 'end' } }
	);
}

1;