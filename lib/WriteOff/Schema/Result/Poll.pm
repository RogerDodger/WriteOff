use utf8;
package WriteOff::Schema::Result::Poll;

use strict;
use warnings;
use base "WriteOff::Schema::Result";

__PACKAGE__->table("polls");

__PACKAGE__->add_columns(
   "id",
   { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
   "user_id",
   { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
   "title",
   { data_type => "text", is_nullable => 0 },
   "voters",
   { data_type => "integer", is_nullable => 0, default_value => 0 },
   "finished",
   { data_type => "bit", is_nullable => 0, default_value => 0 },
   "tallied",
   { data_type => "bit", is_nullable => 0, default_value => 0 },
   "created",
   { data_type => "timestamp", is_nullable => 1 },
   "updated",
   { data_type => "timestamp", is_nullable => 1 },
);

__PACKAGE__->set_primary_key("id");

__PACKAGE__->belongs_to("user", "WriteOff::Schema::Result::User", "user_id");
__PACKAGE__->has_many("ballots", "WriteOff::Schema::Result::Ballot", "poll_id");
__PACKAGE__->has_many("bids", "WriteOff::Schema::Result::Bid", "poll_id");

1;
