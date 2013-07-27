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
	"ip",
	{ data_type => "text", is_nullable => 1 },
	"contents",
	{ data_type => "text", is_nullable => 0 },
	"rating",
	{ data_type => "real", default_value => 1500, is_nullable => 0 },
	"created",
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
	"heats_lefts",
	"WriteOff::Schema::Result::Heat",
	{ "foreign.left" => "self.id" },
	{ cascade_copy => 0, cascade_delete => 0 },
);

__PACKAGE__->has_many(
	"heats_right",
	"WriteOff::Schema::Result::Heat",
	{ "foreign.right" => "self.id" },
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
