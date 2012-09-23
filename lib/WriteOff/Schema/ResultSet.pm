package WriteOff::Schema::ResultSet;

use strict;
use base 'DBIx::Class::ResultSet';

sub now {	
	my $self = shift;
	return $self->result_source->schema->storage->datetime_parser
		->format_datetime( $self->now_dt );
}

sub now_dt {
	return DateTime->now;
	
	return shift->result_source->schema->storage->datetime_parser
		->parse_datetime('2012-09-20 15:00:00');
}

sub created_before {
    my ($self, $datetime) = @_;

    my $date_str = $self->result_source->schema->storage
		->datetime_parser->format_datetime($datetime);

    return $self->search_rs({ created => { '<' => $date_str } });
}

sub created_after {
    my ($self, $datetime) = @_;

    my $date_str = $self->result_source->schema->storage
		->datetime_parser->format_datetime($datetime);

    return $self->search_rs({ created => { '>' => $date_str } });
}

sub seed_order {
	return shift->search_rs(undef, { order_by => { -desc => 'seed' } } );
}

sub order_by {
	my $self = shift;
	
	return $self->search(undef, { order_by => shift });
}

1;