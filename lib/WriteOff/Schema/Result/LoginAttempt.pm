use utf8;
package WriteOff::Schema::Result::LoginAttempt;

use strict;
use warnings;
use base "WriteOff::Schema::Result";

__PACKAGE__->table("login_attempts");

__PACKAGE__->add_columns(
	"id",
	{ data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
	"ip",
	{ data_type => "text", is_nullable => 0 },
	"created",
	{ data_type => "timestamp", is_nullable => 1 },
);

__PACKAGE__->set_primary_key("id");

1;
