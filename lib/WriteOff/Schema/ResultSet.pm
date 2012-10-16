package WriteOff::Schema::ResultSet;

use strict;
use base 'DBIx::Class::ResultSet';

sub datetime_parser {
	return shift->result_source->schema->storage->datetime_parser;
}

sub format_datetime {
	return shift->datetime_parser->format_datetime(shift);
}

sub parse_datetime {
	return shift->datetime_parser->parse_datetime(shift);
}

sub now {	
	my $self = shift;
	return $self->format_datetime( $self->now_dt );
}

sub now_dt {
	return DateTime->now;
	
	return shift->parse_datetime('2012-11-20 01:00:00');
}

sub created_before {
    my ($self, $datetime) = @_;

    my $date_str = $self->format_datetime($datetime);

    return $self->search_rs({ created => { '<' => $date_str } });
}

sub created_after {
    my ($self, $datetime) = @_;

    my $date_str = $self->format_datetime($datetime);

    return $self->search_rs({ created => { '>' => $date_str } });
}

sub seed_order {
	return shift->search_rs(undef, { order_by => { -desc => 'seed' } } );
}

sub order_by {
	my $self = shift;
	
	return $self->search_rs(undef, { order_by => shift });
}

1;