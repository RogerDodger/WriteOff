use utf8;
package WriteOff::Schema::Result::Image;

use strict;
use warnings;
use base "WriteOff::Schema::Result";

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
	"artist",
	{ data_type => "text", default_value => "Anonymous", is_nullable => 0 },
	"website",
	{ data_type => "text", is_nullable => 1 },
	"contents",
	{ data_type => "blob", is_nullable => 0 },
	"thumb",
	{ data_type => "blob", is_nullable => 0 },
	"filesize",
	{ data_type => "integer", is_nullable => 0 },
	"mimetype",
	{ data_type => "text", is_nullable => 0 },
	"seed",
	{ data_type => "real", is_nullable => 1 },
	"created",
	{ data_type => "timestamp", is_nullable => 1 },
	"hovertext",
	{ data_type => "text", is_nullable => 1 },
	"updated",
	{ data_type => "timestamp", is_nullable => 1 },
);

__PACKAGE__->set_primary_key("id");

__PACKAGE__->belongs_to(
	"event",
	"WriteOff::Schema::Result::Event",
	{ id => "event_id" },
	{ is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
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

__PACKAGE__->mk_group_accessors(
	column => 'public_score',
	column => 'story_count',
);

sub type {
	return 'art';
}

sub pos {
	return shift->{__pos} // 0;
}

sub pos_low {
	return shift->{__pos_low} // 0;
}

sub final_score {
	my $self = shift;

	return ($self->story_count || 0) + ($self->public_score || 0 );
}

sub stdev {
	my $self = shift;

	return $self->{__stdev} //= $self->votes->stdev;
}

use overload "==" => '_compare_scores',
	fallback => 1;

sub _compare_scores {
	my( $left, $right ) = @_;

	return 0 unless $left->final_score == $right->final_score;
	1;
}

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
	require WriteOff::Util;

	return WriteOff::Util::simple_uri( $self->id, $self->title );
}

sub version {
	require Digest::MD5;

	return substr Digest::MD5::md5_hex(shift->updated), 0, 5;
}

sub extension {
	my $self = shift;
	$self->mimetype =~ /^image\/(.*)/;

	return $1;
}

sub filename {
	my $self = shift;
	my $prefix = '';
	if ( @_ > 0 ) {
		$prefix = shift;
	}
	
	return $prefix . $self->id . '.' . $self->extension;
}

1;
