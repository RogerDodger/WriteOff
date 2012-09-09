package WriteOff::Schema::ResultSet;

use strict;
use base 'DBIx::Class::ResultSet';

sub now {	
	my $self = shift;
	return $self->result_source->schema->storage->datetime_parser
		->format_datetime( $self->now_dt );
}

sub now_dt {
	my $self = shift;	
	return $self->result_source->schema->storage->datetime_parser
		->parse_datetime('2012-12-25 01:00:00');
}

sub created_before {
    my ($self, $datetime) = @_;

    my $date_str = $self->result_source->schema->storage
		->datetime_parser->format_datetime($datetime);

    return $self->search({ created => { '<' => $date_str } });
}

1;