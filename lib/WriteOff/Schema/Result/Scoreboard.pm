use utf8;
package WriteOff::Schema::Result::Scoreboard;

use strict;
use warnings;
use base "WriteOff::Schema::Result";
use WriteOff::Util;

__PACKAGE__->table("scoreboards");

__PACKAGE__->add_columns(
   "id",
   { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
   "genre_id",
   { data_type => "integer", is_nullable => 0 },
   "format_id",
   { data_type => "integer", is_nullable => 1 },
   "lang",
   { data_type => "text", is_nullable => 0 },
   "body",
   { data_type => "text", is_nullable => 0 },
);

__PACKAGE__->set_primary_key("id");

__PACKAGE__->belongs_to("format", "WriteOff::Schema::Result::Format", "format_id");
__PACKAGE__->belongs_to("genre", "WriteOff::Schema::Result::Genre", "genre_id");

1;
