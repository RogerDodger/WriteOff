use utf8;
package WriteOff::Schema::Result::Round;

use 5.01;
use strict;
use warnings;
use base "WriteOff::Schema::Result";

__PACKAGE__->table("rounds");

__PACKAGE__->add_columns(
	"id",
	{ data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
	"event_id",
	{ data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
	"name",
	{ data_type => "text", is_nullable => 0 },
	"type",
	{ data_type => "text", is_nullable => 0 },
	"start",
	{ data_type => "timestamp", is_nullable => 0 },
	"end",
	{ data_type => "timestamp", is_nullable => 0 },
);

__PACKAGE__->set_primary_key("id");

__PACKAGE__->belongs_to("event", "WriteOff::Schema::Result::Event", "event_id");

1;
