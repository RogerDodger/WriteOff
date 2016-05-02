use utf8;
package WriteOff::Schema::Result::SubFormat;

use strict;
use warnings;
use base "WriteOff::Schema::Result";

__PACKAGE__->table("sub_formats");

__PACKAGE__->add_columns(
	"user_id",
	{ data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
	"format_id",
	{ data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
);

__PACKAGE__->set_primary_key("user_id", "format_id");

__PACKAGE__->belongs_to('user', 'WriteOff::Schema::Result::User', 'user_id');
__PACKAGE__->belongs_to('format', 'WriteOff::Schema::Result::Format', 'format_id');

1;
