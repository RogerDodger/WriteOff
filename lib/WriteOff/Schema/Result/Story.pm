use utf8;
package WriteOff::Schema::Result::Story;

use strict;
use warnings;
use base "WriteOff::Schema::Result";

__PACKAGE__->table("storys");

__PACKAGE__->add_columns(
	"id",
	{ data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
	"contents",
	{ data_type => "text", is_nullable => 0 },
	"wordcount",
	{ data_type => "integer", is_nullable => 0 },
	"indexed",
	{ data_type => 'bit', default_value => 1, is_nullable => 0 },
	"published",
	{ data_type => 'bit', default_value => 1, is_nullable => 0 },
	"created",
	{ data_type => "timestamp", is_nullable => 1 },
	"updated",
	{ data_type => "timestamp", is_nullable => 1 },
);

__PACKAGE__->set_primary_key("id");

__PACKAGE__->belongs_to("entry", "WriteOff::Schema::Result::Entry", { story_id => "id" });
__PACKAGE__->has_many("image_stories", "WriteOff::Schema::Result::ImageStory", "story_id");
__PACKAGE__->many_to_many("images", "image_stories", "image");

sub is_manipulable_by {
	my $self = shift;
	my $user = $self->result_source->schema->resultset('User')->resolve(shift)
		or return 0;

	return $user->is_admin
	    || $self->event->is_organised_by($user)
	    || $self->user_id == $user->id && $self->event->fic_subs_allowed;
}

1;
