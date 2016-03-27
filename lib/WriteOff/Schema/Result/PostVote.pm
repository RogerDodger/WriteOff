use utf8;
package WriteOff::Schema::Result::PostVote;

use strict;
use warnings;
use base "WriteOff::Schema::Result";
use WriteOff::Markup;

__PACKAGE__->table("post_votes");

__PACKAGE__->add_columns(
	"user_id",
	{ data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
	"post_id",
	{ data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
	"value",
	{ data_type => "integer", is_nullable => 0 },
);

__PACKAGE__->set_primary_key("user_id", "post_id");

__PACKAGE__->belongs_to('post', 'WriteOff::Schema::Result::Post', 'post_id');
__PACKAGE__->belongs_to('user', 'WriteOff::Schema::Result::Post', 'user_id');

1;
