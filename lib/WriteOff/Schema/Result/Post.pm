use utf8;
package WriteOff::Schema::Result::Post;

use strict;
use warnings;
use base "WriteOff::Schema::Result";
use WriteOff::Markup;

__PACKAGE__->table("posts");

__PACKAGE__->add_columns(
	"id",
	{ data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
	"artist_id",
	{ data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
	"event_id",
	{ data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
	"entry_id",
	{ data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
	"body",
	{ data_type => "text", is_nullable => 0 },
	"body_render",
	{ data_type => "text", is_nullable => 0 },
	"created",
	{ data_type => "timestamp", is_nullable => 1 },
	"updated",
	{ data_type => "timestamp", is_nullable => 1 },
);

__PACKAGE__->set_primary_key("id");

__PACKAGE__->belongs_to('artist', 'WriteOff::Schema::Result::Artist', 'artist_id', { join_type => "left" });
__PACKAGE__->belongs_to('entry', 'WriteOff::Schema::Result::Entry', 'entry_id', { join_type => "left" });
__PACKAGE__->belongs_to('event', 'WriteOff::Schema::Result::Event', 'event_id', { join_type => "left" });
__PACKAGE__->has_many('reply_children', 'WriteOff::Schema::Result::Reply', 'parent_id');
__PACKAGE__->has_many('reply_parents', 'WriteOff::Schema::Result::Reply', 'child_id');

__PACKAGE__->many_to_many('children', 'reply_children', 'child');
__PACKAGE__->many_to_many('parents', 'reply_parents', 'parent');

# Unique amongst any version of itself, as well as any other post
sub uid {
	my ($self, $user, $entry) = @_;

	join(".", 'post',
		$self->id, $self->updated, $self->artist->updated,
		!!$user->active_artist_id, $user->can_edit($self), !!$entry,
	);
}

sub render {
	my $self = shift;

	my %replies;

	$self->body_render(
		WriteOff::Markup::post($self->body, {
			posts => $self->result_source->resultset->search_rs({}, { join => 'artist' }),
			replies => \%replies,
		})
	);

	$self->parents->delete;
	$self->result_source->schema->resultset('Reply')->populate([
		map {{
			parent_id => $_,
			child_id => $self->id,
		}} keys %replies
	]);

	$self;
}

sub is_manipulable_by {
	my ($self, $user) = @_;

	$self->artist->user_id == $user->id;
}

1;
