use utf8;
package WriteOff::Schema::Result::Vote;

use strict;
use warnings;
use base "WriteOff::Schema::Result";

__PACKAGE__->table("votes");

__PACKAGE__->add_columns(
	"id",
	{ data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
	"record_id",
	{ data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
	"story_id",
	{ data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
	"image_id",
	{ data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
	"value",
	{ data_type => "integer", is_nullable => 1 },
	"percentile",
	{ data_type => "real", is_nullable => 1 },
	"abstained",
	{ data_type => "bit", is_nullable => 0, default_value => 0 },
);

__PACKAGE__->set_primary_key("id");

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
	"record",
	"WriteOff::Schema::Result::VoteRecord",
	{ id => "record_id" },
	{ is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
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

	return $self->story if $self->story_id;
	return $self->image if $self->image_id;
	return undef;
}

1;
