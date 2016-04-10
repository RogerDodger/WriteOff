package WriteOff::Schema::ResultSet::Schedule;

use strict;
use base 'WriteOff::Schema::ResultSet';

sub active {
	my $self = shift;

	$self->search({
		next => { '<=' =>
			$self->format_datetime($self->now_dt->clone->add(days => 2))
		}
	});
}

1;
