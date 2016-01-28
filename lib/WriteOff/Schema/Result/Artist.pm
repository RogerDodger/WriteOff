use utf8;
package WriteOff::Schema::Result::Artist;

use strict;
use warnings;
use base "WriteOff::Schema::Result";
use WriteOff::Award;

__PACKAGE__->table("artists");

__PACKAGE__->add_columns(
	"id",
	{ data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
	"user_id",
	{ data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
	"name",
	{ data_type => "text", is_nullable => 0 },
	"created",
	{ data_type => "timestamp", is_nullable => 1 },
);

__PACKAGE__->set_primary_key("id");

__PACKAGE__->has_many("entrys", "WriteOff::Schema::Result::Entry", "artist_id");
__PACKAGE__->has_many("theorys", "WriteOff::Schema::Result::Theory", "artist_id");
__PACKAGE__->belongs_to("user", "WriteOff::Schema::Result::User", "user_id");

1;
