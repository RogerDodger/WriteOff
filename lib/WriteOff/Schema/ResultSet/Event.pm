package WriteOff::Schema::ResultSet::Event;

use strict;
use base 'DBIx::Class::ResultSet';

sub active_events {	
	my $self = shift;
	return $self->search({end => { '>' => $self->_now } });
}

sub old_events {
	my $self = shift;
	return $self->search({end => { '<' => $self->_now} });
}

sub _now {	
	return shift->result_source->schema->storage->datetime_parser
		->format_datetime( DateTime->now );
}

1;