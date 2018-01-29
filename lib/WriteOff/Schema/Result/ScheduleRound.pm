use utf8;
package WriteOff::Schema::Result::ScheduleRound;

use 5.01;
use strict;
use warnings;
use base "WriteOff::Schema::Result";

__PACKAGE__->table("schedule_rounds");

__PACKAGE__->add_columns(
	"id",
	{ data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
	"schedule_id",
	{ data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
	"name",
	{ data_type => "text", is_nullable => 0 },
	"mode",
	{ data_type => "text", is_nullable => 0 },
	"action",
	{ data_type => "text", is_nullable => 0 },
	"offset",
	{ data_type => "integer", is_nullable => 0 },
	"duration",
	{ data_type => "integer", is_nullable => 0 },
);

__PACKAGE__->set_primary_key("id");

__PACKAGE__->belongs_to("schedule", "WriteOff::Schema::Result::Schedule", "schedule_id");

1;
