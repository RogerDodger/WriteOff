use utf8;
package WriteOff::Schema::Result::Artist;

use strict;
use warnings;
use base "WriteOff::Schema::Result";
use File::Path;
use File::Spec;
use Graphics::ColorObject;
use Imager;
use WriteOff::Award;
use WriteOff::Util;

__PACKAGE__->table("artists");

__PACKAGE__->add_columns(
   "id",
   { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
   "user_id",
   { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
   "admin",
   { data_type => "bit", is_nullable => 0, default_value => 0 },
   "mod",
   { data_type => "bit", is_nullable => 0, default_value => 0 },
   "name",
   { data_type => "text", is_nullable => 0 },
   "name_canonical",
   { data_type => "text", is_nullable => 0 },
   "avatar_id",
   { data_type => "text", is_nullable => 1 },
   "color",
   { data_type => "text", is_nullable => 1 },
   "bio",
   { data_type => "text", is_nullable => 1 },
   "active",
   { data_type => "bit", is_nullable => 0, default_value => 1 },
   "created",
   { data_type => "timestamp", is_nullable => 0 },
   "updated",
   { data_type => "timestamp", is_nullable => 1 },
);

__PACKAGE__->set_primary_key("id");

__PACKAGE__->has_many("artist_genre", "WriteOff::Schema::Result::ArtistGenre", "artist_id");
__PACKAGE__->has_many("entrys", "WriteOff::Schema::Result::Entry", "artist_id");
__PACKAGE__->has_many("posts", "WriteOff::Schema::Result::Post", "artist_id");
__PACKAGE__->has_many("theorys", "WriteOff::Schema::Result::Theory", "artist_id");
__PACKAGE__->belongs_to("user", "WriteOff::Schema::Result::User", "user_id");

sub avatar {
   my $self = shift;
   $self->avatar_url($self->avatar_id);
}

sub avatar_path {
   my ($self, $id) = @_;

   File::Spec->catfile('root' . $self->avatar_url($id));
}

sub avatar_url {
   my ($self, $id) = @_;
   defined $id
      ? '/static/avatar/' . substr($id, 0, 1) . '/' . substr($id, 0, 2) . '/' . $id . '.png'
      : '/static/avatar/default.jpg';
}

sub avatar_write {
   my ($self, $upload) = @_;

   my $token = WriteOff::Util::token;
   my $newId = sprintf "%s-%d-%s", substr($token, 0, 2), $self->id, substr($token, 2, 8);

   my @pathparts = File::Spec->splitpath($self->avatar_path($newId));
   if (!-d $pathparts[1]) {
      File::Path::mkpath($pathparts[1]);
   }

   my $img = Imager->new(file => $upload->tempname) or die Imager->errstr . "\n";
   my $thumb = $img->scale(xpixels => 160, ypixels => 160, type => 'nonprop') or die $img->errstr . "\n";
   $thumb->write(file => $self->avatar_path($newId), type => 'png') or die $thumb->errstr . "\n";

   if (defined $self->avatar_id) {
      unlink $self->avatar_path($self->avatar_id);
   }
   $self->avatar_id($newId);
   $self->avatar_write_color($thumb);
}

sub avatar_write_color {
   my ($self, $img) = @_;

   if (!$img) {
      $self->avatar_id
         and $img = Imager->new(file => $self->avatar_path($self->avatar_id))
         or return $self;
   }

   my $pal = $img->to_paletted({ make_colors => 'webmap' });

   my @colors = map {
      $pal->getpixel(
         x => [ 0 .. $pal->getwidth - 1 ],
         y => [ $_ ],
      );
   } 0 .. $pal->getheight - 1;

   my @rgb = map {
      my $i = $_;
      WriteOff::Util::avg(map { ($_->rgba)[$i] } @colors)
   } 0..2;

   # 2018-10-17
   # Supressing an unavoidable warning from Graphics::ColorObject
   #   Use of uninitialized value within @_ in lc at line 1905.
   local $SIG{__WARN__} = sub {
      warn $_[0] unless $_[0] =~ /ColorObject.pm line 1905/;
   };

   my $lch = Graphics::ColorObject->new_RGB255([@rgb])->as_LCHuv;
   $lch->[0] = 40;
   $lch->[1] = 30;

   my $web = "#" . lc Graphics::ColorObject->new_LCHuv($lch)->as_RGBhex;

   $self->color($web);
   $self;
}

sub color_dark {
   my $self = shift;
   return if !$self->color;

   # Same as above
   local $SIG{__WARN__} = sub {
      warn $_[0] unless $_[0] =~ /ColorObject.pm line 1905/;
   };

   my $lch = Graphics::ColorObject->new_RGBhex($self->color)->as_LCHuv;
   $lch->[0] /= 2;
   "#" . Graphics::ColorObject->new_LCHuv($lch)->as_RGBhex;
}

sub id_uri {
   my $self = shift;
   WriteOff::Util::simple_uri($self->id, $self->name);
}

sub is_manipulable_by {
   my ($self, $user) = @_;

   $self->user_id == $user->id;
}

1;
