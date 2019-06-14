use utf8;
package WriteOff::Schema::Result::ArtistGenre;

use strict;
use warnings;
use base "WriteOff::Schema::Result";

__PACKAGE__->table("artist_genre");

__PACKAGE__->add_columns(
   "artist_id",
   { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
   "genre_id",
   { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
   "role",
   { data_type => "text", is_nullable => 0 },
   "created",
   { data_type => "timestamp", is_nullable => 1 },
);

__PACKAGE__->set_primary_key("artist_id", "genre_id");

__PACKAGE__->belongs_to("artist", "WriteOff::Schema::Result::Artist", "artist_id");
__PACKAGE__->belongs_to("genre", "WriteOff::Schema::Result::Genre", "genre_id");

1;
