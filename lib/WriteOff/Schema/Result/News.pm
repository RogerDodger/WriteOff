use utf8;
package WriteOff::Schema::Result::News;

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
	"title",
	{ data_type => "text", is_nullable => 0 },
	"body",
	{ data_type => "text", is_nullable => 0 },
	"body_render",
	{ data_type => "text", is_nullable => 0 },
	"created",
	{ data_type => "timestamp", is_nullable => 0 },
	"edited",
	{ data_type => "timestamp", is_nullable => 0 }
);

__PACKAGE__->set_primary_key("id");

__PACKAGE__->belongs_to('artist', 'WriteOff::Schema::Result::Artist', 'artist_id', { join_type => "left" });

sub render {
	my $self = shift;
	$self->update({ body_render => WriteOff::Markup::blog($self->body) });
	$self;
}

1;
