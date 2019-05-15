use utf8;
package WriteOff::Schema::Result::Vote;

use strict;
use warnings;
use base "WriteOff::Schema::Result";

__PACKAGE__->table("votes");

__PACKAGE__->add_columns(
   "id",
   { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
   "ballot_id",
   { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
   "entry_id",
   { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
   "value",
   { data_type => "integer", is_nullable => 1 },
   "abstained",
   { data_type => "bit", is_nullable => 0, default_value => 0 },
);

__PACKAGE__->set_primary_key("id");

__PACKAGE__->belongs_to("entry", "WriteOff::Schema::Result::Entry", "entry_id");
__PACKAGE__->belongs_to("ballot", "WriteOff::Schema::Result::Ballot", "ballot_id");

1;
