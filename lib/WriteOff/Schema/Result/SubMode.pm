use utf8;
package WriteOff::Schema::Result::SubMode;

use strict;
use warnings;
use base "WriteOff::Schema::Result";
use WriteOff::Mode;

__PACKAGE__->table("sub_modes");

__PACKAGE__->add_columns(
   "user_id",
   { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
   "mode_id",
   { data_type => "integer", is_nullable => 0 },
);

__PACKAGE__->set_primary_key("user_id", "mode_id");

__PACKAGE__->belongs_to('user', 'WriteOff::Schema::Result::User', 'user_id');

sub mode { WriteOff::Mode->find(@_) }

1;
