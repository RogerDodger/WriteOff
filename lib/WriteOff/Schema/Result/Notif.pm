use utf8;
package WriteOff::Schema::Result::Notif;

use strict;
use warnings;
use base "WriteOff::Schema::Result";
use WriteOff::Notif;

__PACKAGE__->table("notifs");

__PACKAGE__->add_columns(
   "id",
   { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
   "notif_id",
   { data_type => "integer", is_nullable => 0 },
   "user_id",
   { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
   "post_id",
   { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
   "read",
   { data_type => "boolean", is_nullable => 0, default_value => 0 },
   "created",
   { data_type => "timestamp", is_nullable => 1 },
);

__PACKAGE__->set_primary_key("id");

__PACKAGE__->belongs_to("user", "WriteOff::Schema::Result::User", "user_id");
__PACKAGE__->belongs_to("post", "WriteOff::Schema::Result::Post", "post_id",  { join_type => 'LEFT' });

for my $meth (qw/string/) {
   eval qq{
      sub $meth {
         WriteOff::Notif->new(shift->notif_id)->$meth;
      }
   }
}

1;
