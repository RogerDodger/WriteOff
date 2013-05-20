use utf8;
package WriteOff::Schema::Result::UserRole;

use strict;
use warnings;
use base "WriteOff::Schema::Result";

__PACKAGE__->table("user_role");

__PACKAGE__->add_columns(
	"user_id",
	{ data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
	"role_id",
	{ data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
);

__PACKAGE__->set_primary_key("user_id", "role_id");

__PACKAGE__->belongs_to(
	"role",
	"WriteOff::Schema::Result::Role",
	{ id => "role_id" },
	{ is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);

__PACKAGE__->belongs_to(
	"user",
	"WriteOff::Schema::Result::User",
	{ id => "user_id" },
	{ is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);

1;
