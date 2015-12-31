use utf8;
package WriteOff::Schema::Result::Prompt;

use strict;
use warnings;
use base "WriteOff::Schema::Result";

__PACKAGE__->table("prompts");

__PACKAGE__->add_columns(
	"id",
	{ data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
	"event_id",
	{ data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
	"user_id",
	{ data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
	"contents",
	{ data_type => "text", is_nullable => 0 },
	"score",
	{ data_type => "integer", is_nullable => 1 },
	"created",
	{ data_type => "timestamp", is_nullable => 1 },
);

__PACKAGE__->set_primary_key("id");

__PACKAGE__->belongs_to("event", "WriteOff::Schema::Result::Event", "event_id");
__PACKAGE__->belongs_to("user", "WriteOff::Schema::Result::User", "user_id");

sub title {
	return shift->contents;
}

sub is_manipulable_by {
	my $self = shift;
	my $user = $self->result_source->schema->resultset('User')->resolve(shift)
		or return 0;

	return 1 if $user->is_admin
	         || $self->event->is_organised_by($user)
	         || $self->user_id == $user->id && $self->event->prompt_subs_allowed;
	0;
}

sub id_uri {
	my $self = shift;
	require WriteOff::Util;

	return WriteOff::Util::simple_uri($self->id, $self->contents);
}

1;
