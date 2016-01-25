use utf8;
package WriteOff::Schema::Result::PromptVote;

use strict;
use warnings;
use base "WriteOff::Schema::Result";

__PACKAGE__->table("prompt_votes");

__PACKAGE__->add_columns(
	"user_id",
	{ data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
	"prompt_id",
	{ data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
	"value",
	{ data_type => "integer", is_nullable => 1 },
);

__PACKAGE__->set_primary_key("user_id", "prompt_id");

__PACKAGE__->belongs_to("user", "WriteOff::Schema::Result::User", "user_id");
__PACKAGE__->belongs_to("prompt", "WriteOff::Schema::Result::Prompt", "prompt_id");

1;
