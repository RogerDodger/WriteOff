package WriteOff::Schema::ResultSet;

use strict;
use base 'DBIx::Class::ResultSet';
require WriteOff::DateTime;
require WriteOff::Util;

sub datetime_parser {
	shift->result_source->schema->storage->datetime_parser;
}

sub format_datetime {
	shift->datetime_parser->format_datetime(shift);
}

sub parse_datetime {
	shift->datetime_parser->parse_datetime(shift);
}

sub now {
	my $self = shift;
	$self->format_datetime($self->now_dt);
}

sub now_dt {
	WriteOff::DateTime->now;
}

sub now_leeway {
	my $self = shift;
	$self->format_datetime($self->now_dt->clone->subtract(minutes => WriteOff::Util::LEEWAY));
}

sub created_before {
	my ($self, $datetime) = @_;
	$self->search_rs({ created => { '<' => $self->format_datetime($datetime) } });
}

sub created_after {
	my ($self, $datetime) = @_;
	$self->search_rs({ created => { '>' => $self->format_datetime($datetime) } });
}

sub order_by {
	my $self = shift;
	$self->search_rs(undef, { order_by => shift });
}

sub join {
	my $self = shift;
	$self->search_rs(undef, { join => shift });
}

1;
