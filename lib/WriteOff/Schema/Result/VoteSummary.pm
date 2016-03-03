package WriteOff::Schema::Result::VoteSummary;

use base qw/DBIx::Class::Core/;
use WriteOff::Award;

__PACKAGE__->table_class('DBIx::Class::ResultSource::View');
__PACKAGE__->table('vote_summary');

__PACKAGE__->add_columns(
	"left",
	{ data_type => "integer" },
	"right",
	{ data_type => "integer" },
);

__PACKAGE__->result_source_instance->is_virtual(1);

my $subq = q{
	SELECT COUNT(*)
		FROM votes inn
		WHERE inn.ballot_id=me.ballot_id
		AND inn.abstained=0
		AND inn.value IS NOT NULL
};

__PACKAGE__->result_source_instance->view_definition(qq{
	SELECT
		($subq AND value > me.value) AS left,
		($subq AND value < me.value) AS right
	FROM votes me
	LEFT JOIN ballots ON ballots.id=me.ballot_id
	WHERE me.entry_id = ?
	AND ballots.round_id = ?
	AND (left + right) > 0
});

__PACKAGE__->result_source_instance->deploy_depends_on([
	"WriteOff::Schema::Result::Ballot",
	"WriteOff::Schema::Result::Entry",
	"WriteOff::Schema::Result::Event",
	"WriteOff::Schema::Result::Vote",
]);

1;
