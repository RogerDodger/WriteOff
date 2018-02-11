use utf8;
package WriteOff::Schema::Result::ArtistEvent;

use strict;
use warnings;
use base "WriteOff::Schema::Result";

__PACKAGE__->table("artist_event");

__PACKAGE__->add_columns(
	"artist_id",
	{ data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
	"event_id",
	{ data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
	"role",
	{ data_type => "text", is_nullable => 0 },
);

__PACKAGE__->set_primary_key("artist_id", "event_id", "role");

__PACKAGE__->belongs_to("artist", "WriteOff::Schema::Result::Artist", "artist_id");
__PACKAGE__->belongs_to("event", "WriteOff::Schema::Result::Event", "event_id");

1;
