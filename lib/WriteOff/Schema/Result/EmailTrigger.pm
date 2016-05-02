use utf8;
package WriteOff::Schema::Result::EmailTrigger;

use strict;
use warnings;
use base "WriteOff::Schema::Result";
use WriteOff::Util;

__PACKAGE__->table("email_triggers");

__PACKAGE__->add_columns(
	"id",
	{ data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
	"name",
	{ data_type => "text", is_nullable => 0 },
	"template",
	{ data_type => "text", is_nullable => 0 },
	"prompt_in_subject",
	{ data_type => "bit", is_nullable => 0, default_value => 1, },
);

__PACKAGE__->set_primary_key("id");

__PACKAGE__->has_many("subs", "WriteOff::Schema::Result::SubTrigger", "trigger_id");

1;
