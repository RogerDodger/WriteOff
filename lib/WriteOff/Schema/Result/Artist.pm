use utf8;
package WriteOff::Schema::Result::Artist;

use strict;
use warnings;
use base "WriteOff::Schema::Result";
use WriteOff::Award;

__PACKAGE__->table("artists");

__PACKAGE__->add_columns(
	"id",
	{ data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
	"name",
	{ data_type => "text", is_nullable => 0 },
	"user_id",
	{ data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
	"score",
	{ data_type => "real", is_nullable => 1 },
);

__PACKAGE__->set_primary_key("id");

__PACKAGE__->add_unique_constraint("name_unique", ["name"]);

__PACKAGE__->has_many(
	"artist_awards",
	"WriteOff::Schema::Result::ArtistAward",
	{ "foreign.artist_id" => "self.id" },
	{ cascade_copy => 0, cascade_delete => 0 },
);

__PACKAGE__->has_many(
	"scores",
	"WriteOff::Schema::Result::Score",
	{ "foreign.artist_id" => "self.id" },
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

__PACKAGE__->mk_group_accessors(column => 'rank');

sub awards {
	shift->artist_awards->awards;
}

sub recalculate_score {
	my $self = shift;

	$self->update({
		score => $self->scores->get_column('value')->sum_rs->as_query
	});
}

1;
