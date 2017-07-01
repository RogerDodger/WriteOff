package WriteOff::Schema::Result::Score;

use base qw/DBIx::Class::Core/;
use WriteOff::Award;
use WriteOff::Util ();

__PACKAGE__->table_class('DBIx::Class::ResultSource::View');
__PACKAGE__->table('scoresx');

__PACKAGE__->add_columns(
	"id",
	{ data_type => "integer" },
	"name",
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
	  SUM(entrys.score_genre) AS score_genre,
	  SUM(entrys.score_format) AS score_format
	FROM
	  artists
	CROSS JOIN
	  entrys ON artists.id=entrys.artist_id AND entrys.score IS NOT NULL
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
	"WriteOff::Schema::Result::Entry",
	"WriteOff::Schema::Result::Event",
]);

sub id_uri {
	my $self = shift;
	WriteOff::Util::simple_uri $self->id, $self->name;
}

sub tally_awards {
	my ($self, $awards, $cols) = @_;

	my %bin = map { $_->award_id => 0 } @$cols;
	$bin{$_->award_id}++ for $awards->search(
		{ "entry.artist_id" => $self->id },
		{ join => 'entry' },
	)->all;

	my @tally;
	for my $award (@$cols) {
		push @tally, {
			award => $award,
			count => $bin{$award->award_id},
		};
	}

	return \@tally;
}

1;
