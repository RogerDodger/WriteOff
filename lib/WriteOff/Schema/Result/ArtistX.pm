package WriteOff::Schema::Result::ArtistX;

use base qw/DBIx::Class::Core/;
use WriteOff::Award qw/sort_awards/;
use WriteOff::Schema::Result::Artist;

__PACKAGE__->table_class('DBIx::Class::ResultSource::View');
__PACKAGE__->table('artistsx');

__PACKAGE__->add_columns(
	"id",
	{ data_type => "integer" },
	"name",
	{ data_type => "text" },
	"color",
	{ data_type => "text" },
	"avatar_id",
	{ data_type => "text" },
	"award_ids",
	{ data_type => "text" },
	"score_genre",
	{ data_type => "real" },
	"score_format",
	{ data_type => "real" },
);

__PACKAGE__->result_source_instance->is_virtual(1);

__PACKAGE__->result_source_instance->view_definition(q{
	SELECT
	  artists.id AS id,
	  artists.name AS name,
	  artists.color AS color,
	  artists.avatar_id AS avatar_id,
	  GROUP_CONCAT(entrys.award_ids) AS award_ids,
	  SUM(entrys.score_genre) AS score_genre,
	  SUM(entrys.score_format) AS score_format
	FROM
	  artists
	CROSS JOIN
	-- The awards need to be concatenated both here and above, otherwise the
	-- score sums will get duplicates for any entry with 2 or more awards
	  (
	    SELECT
	      entrys.*,
	      GROUP_CONCAT(award_id) AS award_ids
	    FROM
	      entrys
	    LEFT JOIN
	      awards ON entrys.id=awards.entry_id
	    GROUP BY
	      entrys.id
	  ) AS entrys
	    ON artists.id=entrys.artist_id AND entrys.score IS NOT NULL
	CROSS JOIN
	  events ON entrys.event_id=events.id
	WHERE
	      (?1 != 'image_id' OR image_id IS NOT NULL)
	  AND (?1 != 'story_id' OR story_id IS NOT NULL)
	  AND score IS NOT NULL
	  AND artist_public=1
	  AND genre_id = ?2
	  AND (?3 IS NULL OR format_id = ?3)
	GROUP BY
	  artists.id
});

__PACKAGE__->result_source_instance->deploy_depends_on([
	"WriteOff::Schema::Result::Artist",
	"WriteOff::Schema::Result::Award",
	"WriteOff::Schema::Result::Entry",
	"WriteOff::Schema::Result::Event",
]);

*avatar = \&WriteOff::Schema::Result::Artist::avatar;
*avatar_url = \&WriteOff::Schema::Result::Artist::avatar_url;

sub awards {
	my $self = shift;
	return if !$self->award_ids;
	$self->{__awards} //= [
		sort_awards
		  map { WriteOff::Award->new($_) }
		    split ",", $self->award_ids
	];
}

*color_dark = \&WriteOff::Schema::Result::Artist::color_dark;
*id_uri = \&WriteOff::Schema::Result::Artist::id_uri;

1;
