use utf8;
package WriteOff::Schema::Result::Score;

use strict;
use warnings;
use base "WriteOff::Schema::Result";

__PACKAGE__->table("scores");

__PACKAGE__->add_columns(
	"id",
	{ data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
	"artist_id",
	{ data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
	"event_id",
	{ data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
	"story_id",
	{ data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
	"image_id",
	{ data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
	"type",
	{ data_type => "text", is_nullable => 1 },
	"value",
	{ data_type => "real", is_nullable => 1 },
	"orig",
	{ data_type => "real", is_nullable => 1 },
);

__PACKAGE__->set_primary_key("id");

__PACKAGE__->belongs_to(
	"artist",
	"WriteOff::Schema::Result::Artist",
	{ id => "artist_id" },
	{ is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);

__PACKAGE__->belongs_to(
	"event",
	"WriteOff::Schema::Result::Event",
	{ id => "event_id" },
	{ is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);

__PACKAGE__->belongs_to(
	"image",
	"WriteOff::Schema::Result::Image",
	{ id => "image_id" },
	{
		is_deferrable => 1,
		join_type     => "LEFT",
		on_delete     => "CASCADE",
		on_update     => "CASCADE",
	},
);

__PACKAGE__->belongs_to(
	"story",
	"WriteOff::Schema::Result::Story",
	{ id => "story_id" },
	{
		is_deferrable => 1,
		join_type     => "LEFT",
		on_delete     => "CASCADE",
		on_update     => "CASCADE",
	},
);

sub item {
	my $self = shift;

	return $self->story if defined $self->story_id;
	return $self->image if defined $self->image_id;
	return undef;
}

1;
