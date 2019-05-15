use utf8;
package WriteOff::Schema::Result::Bid;

use strict;
use warnings;
use base "WriteOff::Schema::Result";

__PACKAGE__->table("bids");

__PACKAGE__->add_columns(
   "id",
   { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
   "poll_id",
   { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
   "name",
   { data_type => "text", is_nullable => 0 },
   "rating",
   { data_type => "real", is_nullable => 1 },
   "error",
   { data_type => "real", is_nullable => 1 },
);

__PACKAGE__->set_primary_key("id");

__PACKAGE__->belongs_to("polls", "WriteOff::Schema::Result::Poll", "poll_id");
__PACKAGE__->has_many("votes", "WriteOff::Schema::Result::BidVote", "bid_id");

1;
