package WriteOff::Schema::Result::Scoreboard;

use base qw/DBIx::Class::Core/;
use WriteOff::Util qw/maybe/;
use WriteOff::Award;

__PACKAGE__->table_class('DBIx::Class::ResultSource::View');
__PACKAGE__->table('scoreboards');

__PACKAGE__->add_columns(
	"id",
	{ data_type => "integer" },
	"name",
	{ data_type => "text" },
	"score",
	{ data_type => "real" },
	"format_id",
	{ data_type => "integer", is_foreign_key => 1 },
	"genre_id",
	{ data_type => "integer", is_foreign_key => 1 },
);

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

__PACKAGE__->result_source_instance->view_definition(q{
	SELECT
		artists.id AS id,
		artists.name AS name,
		SUM(scores.value) AS score,
		genre_id AS genre_id,
		format_id AS format_id
	FROM
		artists
	CROSS JOIN
		scores ON artists.id=scores.artist_id
	CROSS JOIN
		events ON scores.event_id=events.id
	GROUP BY
		artists.id, genre_id, format_id

	UNION

	SELECT
		artists.id AS id,
		artists.name AS name,
		SUM(scores.value) AS score,
		genre_id AS genre_id,
		NULL AS format_id
	FROM
		artists
	CROSS JOIN
		scores ON artists.id=scores.artist_id
	CROSS JOIN
		events ON scores.event_id=events.id
	GROUP BY
		artists.id, genre_id

	UNION

	SELECT
		artists.id AS id,
		artists.name AS name,
		SUM(scores.value) AS score,
		NULL AS genre_id,
		NULL AS format_id
	FROM
		artists
	CROSS JOIN
		scores ON artists.id=scores.artist_id
	GROUP BY
		artists.id

	ORDER BY score DESC
});

__PACKAGE__->result_source_instance->deploy_depends_on([
	"WriteOff::Schema::Result::Artist",
	"WriteOff::Schema::Result::Event",
]);

sub tally_awards {
	my $self = shift;

	my %tally;
	$tally{$_}++ for $self->artist_awards->search(
		{
			maybe("event.format_id" => $self->format_id),
			maybe("event.genre_id" => $self->genre_id),
		},
		{ join => 'event' }
	)->get_column('award_id')->all;

	return \%tally;
}

1;
