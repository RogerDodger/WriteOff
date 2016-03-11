use utf8;
package WriteOff::Schema::Result::Artist;

use strict;
use warnings;
use base "WriteOff::Schema::Result";
use File::Path;
use File::Spec;
use Imager;
use WriteOff::Award;
use WriteOff::Util;

__PACKAGE__->table("artists");

__PACKAGE__->add_columns(
	"id",
	{ data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
	"user_id",
	{ data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
	"name",
	{ data_type => "text", is_nullable => 0 },
	"avatar_id",
	{ data_type => "text", is_nullable => 1 },
	"bio",
	{ data_type => "text", is_nullable => 1 },
	"created",
	{ data_type => "timestamp", is_nullable => 1 },
);

__PACKAGE__->set_primary_key("id");

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
	File::Path::mkpath($pathparts[1]);

	my $img = Imager->new(file => $upload->tempname) or die Imager->errstr;
	my $thumb = $img->scale(xpixels => 160, ypixels => 160, type => 'nonprop') or die $img->errstr;
	$thumb->write(file => $self->avatar_path($newId), type => 'png') or die $thumb->errstr;

	if (defined $self->avatar_id) {
		unlink $self->avatar_path($self->avatar_id);
	}
	$self->avatar_id($newId);
}

sub id_uri {
	my $self = shift;
	WriteOff::Util::simple_uri($self->id, $self->name);
}

1;
