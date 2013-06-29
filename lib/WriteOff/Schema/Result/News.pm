use utf8;
package WriteOff::Schema::Result::News;

use strict;
use warnings;
use base "WriteOff::Schema::Result";

__PACKAGE__->table("news");

__PACKAGE__->add_columns(
	"id",
	{ data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
	"user_id",
	{ data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
	"title",
	{ data_type => "text", is_nullable => 1 },
	"body",
	{ data_type => "text", is_nullable => 1 },
	"created",
	{ data_type => "timestamp", is_nullable => 1 },
	"updated",
	{ data_type => "timestamp", is_nullable => 1 },
);

__PACKAGE__->set_primary_key("id");

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

sub id_uri {
	my $self = shift;

	return WriteOff::Util::simple_uri($self->id, $self->title);
}

sub is_edited {
	my $self = shift;

	return $self->created->add( minutes => 3 ) <= $self->updated;
}

1;
