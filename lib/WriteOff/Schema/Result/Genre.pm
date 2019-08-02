use utf8;
package WriteOff::Schema::Result::Genre;

use strict;
use warnings;
use base "WriteOff::Schema::Result";
use Imager;
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
__PACKAGE__->has_many("schedules", "WriteOff::Schema::Result::Schedule", "genre_id");
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
      ? "/static/banner/" . substr($id, 0, 2) . "/$id.jpg"
      : '/static/banner/default.jpg';
}

sub banner_write {
   my ($self, $upload) = @_;

   my $token = WriteOff::Util::token;
   my $newId = sprintf "%s-%d-%s", substr($token, 0, 2), $self->id, substr($token, 2, 8);

   my @pathparts = File::Spec->splitpath($self->banner_path($newId));
   if (!-d $pathparts[1]) {
      File::Path::mkpath($pathparts[1]);
   }

   my $img = Imager->new(file => $upload->tempname, png_ignore_benign_errors => 1)
      or die Imager->errstr . "\n";
   my $scale = $img->scale(xpixels => 1024, ypixels => 192) or die $img->errstr . "\n";
   my $crop = $scale->crop(width => 1024, height => 192) or die $scale->errstr . "\n";
   $crop->write(file => $self->banner_path($newId), jpegquality => 90, jpeg_optimize => 1)
      or die $crop->errstr . "\n";

   if (defined $self->banner_id) {
      unlink $self->banner_path($self->banner_id);
   }
   $self->banner_id($newId);
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

sub recalc_completion {
   my $self = shift;
   my $cap = shift // 20;
   return if $self->established;

   my $c = $self->subs->count;
   if ($c >= $cap) {
      $self->update({
         established => 1,
         completion => undef,
      });
   }
   else {
      $self->update({ completion => $c });
   }
}

1;
