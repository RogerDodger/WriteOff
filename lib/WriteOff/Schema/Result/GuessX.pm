use utf8;
package WriteOff::Schema::Result::GuessX;

use strict;
use warnings;
use base "DBIx::Class::Core";

__PACKAGE__->table_class('DBIx::Class::ResultSource::View');
__PACKAGE__->table('guessesx');

__PACKAGE__->result_source_instance->is_virtual(1);
__PACKAGE__->result_source_instance->view_definition(q{
	SELECT
		g.id AS id,
		g.entry_id AS entry_id,
		g.theory_id AS theory_id,
		g.artist_id AS guessed_id,
		e.artist_id AS actual_id,
		(e.artist_id = g.artist_id) AS correct
	FROM guesses g
	LEFT JOIN theorys t ON g.theory_id = t.id
	LEFT JOIN entrys e ON g.entry_id = e.id
	WHERE e.event_id = ?
});

__PACKAGE__->add_columns(
	"id",
	{ data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
	"theory_id",
	{ data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
	"entry_id",
	{ data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
	"guessed_id",
	{ data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
	"actual_id",
	{ data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
	"correct",
	{ data_type => "boolean", is_nullable => 1 },
);

1;
