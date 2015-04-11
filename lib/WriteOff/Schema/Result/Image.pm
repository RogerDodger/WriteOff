use utf8;
package WriteOff::Schema::Result::Image;

use strict;
use warnings;
use base "WriteOff::Schema::Result";
use Digest::MD5;
use Image::Magick;
use File::Spec;
use File::Copy;
use WriteOff::Util qw/simple_uri/;

__PACKAGE__->table("images");

__PACKAGE__->add_columns(
	"id",
	{ data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
	"event_id",
	{ data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
	"user_id",
	{ data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
	"ip",
	{ data_type => "text", is_nullable => 1 },
	"title",
	{ data_type => "text", is_nullable => 0 },
	"artist_id",
	{ data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
	"website",
	{ data_type => "text", is_nullable => 1 },
	"hovertext",
	{ data_type => "text", is_nullable => 1 },
	"contents",
	{ data_type => "blob", is_nullable => 0 },
	"thumb",
	{ data_type => "blob", is_nullable => 0 },
	"filesize",
	{ data_type => "integer", is_nullable => 0 },
	"mimetype",
	{ data_type => "text", is_nullable => 0 },
	"version",
	{ data_type => "text", is_nullable => 0 },
	"seed",
	{ data_type => "real", is_nullable => 1 },
	"public_score",
	{ data_type => "real", is_nullable => 0 },
	"public_stdev",
	{ data_type => "real", is_nullable => 0 },
	"rank",
	{ data_type => "integer", is_nullable => 1 },
	"rank_low",
	{ data_type => "integer", is_nullable => 1 },
	"created",
	{ data_type => "timestamp", is_nullable => 1 },
	"updated",
	{ data_type => "timestamp", is_nullable => 1 },
);

__PACKAGE__->set_primary_key("id");

__PACKAGE__->belongs_to(
	"artist",
	"WriteOff::Schema::Result::Artist",
	{ id => "artist_id" },
	{ is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);

__PACKAGE__->has_many(
	"artist_awards",
	"WriteOff::Schema::Result::ArtistAward",
	{ "foreign.image_id" => "self.id" },
	{ cascade_copy => 0, cascade_delete => 0 },
);

__PACKAGE__->belongs_to(
	"event",
	"WriteOff::Schema::Result::Event",
	{ id => "event_id" },
	{ is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);

__PACKAGE__->has_many(
	"guesses",
	"WriteOff::Schema::Result::Guess",
	{ "foreign.story_id" => "self.id" },
	{ cascade_copy => 0, cascade_delete => 0 },
);

__PACKAGE__->has_many(
	"image_stories",
	"WriteOff::Schema::Result::ImageStory",
	{ "foreign.image_id" => "self.id" },
	{ cascade_copy => 0, cascade_delete => 0 },
);

__PACKAGE__->has_many(
	"scores",
	"WriteOff::Schema::Result::Score",
	{ "foreign.image_id" => "self.id" },
	{ cascade_copy => 0, cascade_delete => 0 },
);

__PACKAGE__->belongs_to(
	"user",
	"WriteOff::Schema::Result::User",
	{ id => "user_id" },
	{
		is_deferrable => 1,
		join_type     => "LEFT",
		on_delete     => "CASCADE",
		on_update     => "CASCADE",
	},
);

__PACKAGE__->has_many(
	"votes",
	"WriteOff::Schema::Result::Vote",
	{ "foreign.image_id" => "self.id" },
	{ cascade_copy => 0, cascade_delete => 0 },
);

__PACKAGE__->many_to_many("stories", "image_stories", "story");

sub awards {
	return shift->artist_awards->awards;
}

sub type {
	return 'art';
}

sub pos {
	return shift->rank;
}

sub pos_low {
	return shift->rank_low;
}

sub final_score {
	return shift->public_score;
}

sub stdev {
	return shift->public_stdev;
}

use overload "==" => '_compare_scores',
	fallback => 1;

sub _compare_scores {
	my( $left, $right ) = @_;

	return 0 unless $left->final_score == $right->final_score;
	1;
}

sub detected { 1 }

sub clean {
	my $self = shift;

	my $fn = $self->filename;
	for my $dir (qw{root/static/art root/static/art/thumb}) {
		for my $img (glob File::Spec->catfile($dir, $self->id . '-*')) {
			$img =~ qr{$fn$} or unlink $img;
		}
	}
}

BEGIN { *controversial = \&public_stdev; }

sub is_manipulable_by {
	my $self = shift;
	my $user = $self->result_source->schema->resultset('User')->resolve(shift)
		or return 0;

	return 1 if $user->is_admin;
	return 1 if $self->event->is_organised_by( $user );
	return 1 if $self->user_id == $user->id && $self->event->art_subs_allowed;

	0;
}

sub id_uri {
	my $self = shift;

	return simple_uri $self->id, $self->title;
}

sub extension {
	return shift->mimetype =~ s{^image/}{}r =~ s{jpeg}{jpg}r;
}

sub filename {
	my $self = shift;
	return $self->id . '-' . $self->version . '.' .$self->extension;
}

sub path {
	my ($self, $thumb) = @_;
	'/static/art/' . ('thumb/' x!! $thumb) . $self->filename;
}

sub write {
	my ($self, $img) = @_;
	$self->version(substr Digest::MD5->md5_hex(time . rand() . $$), -6);

	my $magick = Image::Magick->new;
	$magick->Read($img);
	$magick->Resize(geometry => '225x225');

	my $e = $magick->Write(File::Spec->catfile('root', $self->path('thumb')));
	return $e if $e;

	copy($img, File::Spec->catfile('root', $self->path)) or return $!;

	$self->update;
	$self->clean;
	0;
}

1;
