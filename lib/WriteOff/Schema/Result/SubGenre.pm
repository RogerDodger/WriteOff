use utf8;
package WriteOff::Schema::Result::SubGenre;

use strict;
use warnings;
use base "WriteOff::Schema::Result";

__PACKAGE__->table("sub_genres");

__PACKAGE__->add_columns(
	"user_id",
	{ data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
	"genre_id",
	{ data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
);

__PACKAGE__->set_primary_key("user_id", "genre_id");

__PACKAGE__->belongs_to('user', 'WriteOff::Schema::Result::User', 'user_id');
__PACKAGE__->belongs_to('genre', 'WriteOff::Schema::Result::Genre', 'genre_id');

1;
