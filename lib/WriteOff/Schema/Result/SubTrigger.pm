use utf8;
package WriteOff::Schema::Result::SubTrigger;

use strict;
use warnings;
use base "WriteOff::Schema::Result";

__PACKAGE__->table("sub_triggers");

__PACKAGE__->add_columns(
   "user_id",
   { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
   "trigger_id",
   { data_type => "integer", is_nullable => 0 },
);

__PACKAGE__->set_primary_key("user_id", "trigger_id");

__PACKAGE__->belongs_to('user', 'WriteOff::Schema::Result::User', 'user_id');

sub trigger { WriteOff::EmailTrigger->find(@_) }

1;
