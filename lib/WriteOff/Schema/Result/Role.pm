use utf8;
package WriteOff::Schema::Result::Role;

use strict;
use warnings;
use base "WriteOff::Schema::Result";

__PACKAGE__->table("roles");

__PACKAGE__->add_columns(
	"id",
	{ data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
	"role",
	{ data_type => "text", is_nullable => 0 },
);

__PACKAGE__->set_primary_key("id");

__PACKAGE__->has_many(
	"user_roles",
	"WriteOff::Schema::Result::UserRole",
	{ "foreign.role_id" => "self.id" },
	{ cascade_copy => 0, cascade_delete => 0 },
);

__PACKAGE__->many_to_many("users", "user_roles", "user");

1;
