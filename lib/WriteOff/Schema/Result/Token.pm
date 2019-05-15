use utf8;
package WriteOff::Schema::Result::Token;

use strict;
use warnings;
use base 'WriteOff::Schema::Result';

__PACKAGE__->table('tokens');

__PACKAGE__->add_columns(
   "id",
   { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
   'user_id',
   { data_type => 'integer', is_nullable => 0, is_foreign_key => 1 },
   'type',
   { data_type => 'text', is_nullable => 0 },
   'value',
   { data_type => 'text', is_nullable => 0 },
   'address',
   { data_type => 'text', is_nullable => 1 },
   'expires',
   { data_type => 'timestamp', is_nullable => 0 },
);

__PACKAGE__->set_primary_key('id');
__PACKAGE__->belongs_to("user", "WriteOff::Schema::Result::User", "user_id");

1;
