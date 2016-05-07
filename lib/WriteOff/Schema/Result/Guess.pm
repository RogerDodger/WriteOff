use utf8;
package WriteOff::Schema::Result::Guess;

use strict;
use warnings;
use base "WriteOff::Schema::Result";

__PACKAGE__->table("guesses");

__PACKAGE__->add_columns(
	"id",
	{ data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
	"theory_id",
	{ data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
	"entry_id",
	{ data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
	"artist_id",
	{ data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
);

__PACKAGE__->set_primary_key("id");

__PACKAGE__->belongs_to("artist", "WriteOff::Schema::Result::Artist", "artist_id");
__PACKAGE__->belongs_to("theory", "WriteOff::Schema::Result::Theory", "theory_id");
__PACKAGE__->belongs_to("entry", "WriteOff::Schema::Result::Entry", "entry_id");

sub correct {
	$_[0]->artist_id == $_[0]->entry->artist_id;
}

1;
