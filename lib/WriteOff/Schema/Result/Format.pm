use utf8;
package WriteOff::Schema::Result::Format;

use strict;
use warnings;
use base "WriteOff::Schema::Result";

__PACKAGE__->table("formats");

__PACKAGE__->add_columns(
	"id",
	{ data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
	"name",
	{ data_type => "text", is_nullable => 1 },
	"wc_min",
	{ data_type => "integer", is_nullable => 1 },
	"wc_max",
	{ data_type => "integer", is_nullable => 1 },
);

__PACKAGE__->set_primary_key("id");

__PACKAGE__->has_many("events", "WriteOff::Schema::Result::Event", "format_id");
__PACKAGE__->has_many("subs", "WriteOff::Schema::Result::SubFormat", "format_id");

sub id_uri {
	my $self = shift;
	return WriteOff::Util::simple_uri $self->id, $self->name;
}

1;
