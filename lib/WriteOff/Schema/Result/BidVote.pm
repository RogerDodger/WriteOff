use utf8;
package WriteOff::Schema::Result::BidVote;

use strict;
use warnings;
use base "WriteOff::Schema::Result";

__PACKAGE__->table("bid_votes");

__PACKAGE__->add_columns(
   "id",
   { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
   "ballot_id",
   { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
   "bid_id",
   { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
   "value",
   { data_type => "integer", is_nullable => 1 },
   "abstained",
   { data_type => "bit", is_nullable => 0, default_value => 0 },
);

__PACKAGE__->set_primary_key("id");

__PACKAGE__->belongs_to("bid", "WriteOff::Schema::Result::Bid", "bid_id");
__PACKAGE__->belongs_to("ballot", "WriteOff::Schema::Result::Ballot", "ballot_id");

1;
