use utf8;
package WriteOff::Schema::Result::Genre;

use strict;
use warnings;
use base "WriteOff::Schema::Result";
use File::Spec;
use WriteOff::Util;

__PACKAGE__->table("genres");

__PACKAGE__->add_columns(
   "id",
   { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
   "owner_id",
   { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
   "name",
   { data_type => "text", is_nullable => 1 },
   "descr",
   { data_type => "text", is_nullable => 1 },
   "banner_id",
   { data_type => "text", is_nullable => 1 },
   "color",
   { data_type => "text", is_nullable => 1 },
   "promoted",
   { data_type => "bit", is_nullable => 0, default_value => 0 },
   "established",
   { data_type => "bit", is_nullable => 0, default_value => 0 },
   "completion",
   { data_type => "integer", is_nullable => 1 },
   "created",
   { data_type => "timestamp", is_nullable => 1 },
);

__PACKAGE__->set_primary_key("id");

__PACKAGE__->belongs_to("owner", "WriteOff::Schema::Result::Artist", "owner_id");
__PACKAGE__->has_many("events", "WriteOff::Schema::Result::Event", "genre_id");
__PACKAGE__->has_many("subs", "WriteOff::Schema::Result::SubGenre", "genre_id");
__PACKAGE__->has_many("members", "WriteOff::Schema::Result::ArtistGenre", "genre_id");

sub banner {
   my $self = shift;
   $self->banner_url($self->banner_id);
}

sub banner_path {
   my ($self, $id) = @_;

   File::Spec->catfile('root' . $self->banner_url($id));
}

sub banner_url {
   my ($self, $id) = @_;
   defined $id
      ? "/static/banner/$id.jpg"
      : '/static/banner/default.jpg';
}

sub entry_count {
   my ($self, $id) = @_;

   $self->events->related_resultset('entrys')->count;
}

sub id_uri {
   my $self = shift;
   return WriteOff::Util::simple_uri $self->id, $self->name;
}

sub member {
   my ($self, $aid) = @_;

   return $self->members->search({ artist_id => $aid })->count;
}

1;
