use utf8;
package WriteOff::Schema::Result::Rating;

use 5.01;
use strict;
use warnings;
use base "WriteOff::Schema::Result";

__PACKAGE__->table("ratings");

__PACKAGE__->add_columns(
	"id",
	{ data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
	"round_id",
	{ data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
	"entry_id",
	{ data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
	"value",
	{ data_type => "real", is_nullable => 0 },
	"error",
	{ data_type => "real", is_nullable => 1 },
);

__PACKAGE__->set_primary_key("id");

__PACKAGE__->belongs_to("entry", "WriteOff::Schema::Result::Entry", "entry_id");
__PACKAGE__->belongs_to("round", "WriteOff::Schema::Result::Round", "round_id");

1;
