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

sub leave {
   my $self = shift;
   my $cap = shift // 20;
   my $schema = $self->result_source->schema;
   my $user = $self->artist->user;
   my $group = $self->genre;

   # Delete membership
   $self->delete;

   # Unsub if the user has no other artists in the group
   $schema->resultset('SubGenre')->find($user->id, $group->id)->delete
      if $user
      && !$user->artists
         ->related_resultset('artist_genre')
         ->search({ genre_id => $group->id })
         ->count
      # Don't unsub the owner
      && $group->owner->user_id != $user->id;

   $group->recalc_completion($cap);
}

1;
