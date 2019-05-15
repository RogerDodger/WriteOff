use utf8;
package WriteOff::Schema::Result::Job;

use strict;
use warnings;
use base "WriteOff::Schema::Result";

__PACKAGE__->load_components(qw/InflateColumn::Serializer/);

__PACKAGE__->table("jobs");

__PACKAGE__->add_columns(
   "id",
   { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
   "action",
   { data_type => "text", is_nullable => 0 },
   "at",
   { data_type => "timestamp", is_nullable => 0 },
   "args",
   { data_type => "text", is_nullable => 1, serializer_class => "JSON" },
);

__PACKAGE__->set_primary_key("id");

1;
