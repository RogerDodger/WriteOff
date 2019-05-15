use utf8;
package WriteOff::Schema::Result::Reply;

use strict;
use warnings;
use base "WriteOff::Schema::Result";

__PACKAGE__->table("replys");

__PACKAGE__->add_columns(
   "parent_id",
   { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
   "child_id",
   { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
);

__PACKAGE__->set_primary_key("parent_id", "child_id");

__PACKAGE__->belongs_to('child', 'WriteOff::Schema::Result::Post', 'child_id', { join_type => 'left' });
__PACKAGE__->belongs_to('parent', 'WriteOff::Schema::Result::Post', 'parent_id', { join_type => 'left' });

1;
