use utf8;
package WriteOff::Schema::Result::Award;

use strict;
use warnings;
use base "WriteOff::Schema::Result";

__PACKAGE__->table("awards");

__PACKAGE__->add_columns(
	"id",
	{ data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
	"name",
	{ data_type => "text", is_nullable => 1 },
	"sort_rank",
	{ data_type => "integer", is_nullable => 1 },
);

__PACKAGE__->set_primary_key("id");

__PACKAGE__->add_unique_constraint("name_unique", ["name"]);

__PACKAGE__->has_many(
	"artist_awards",
	"WriteOff::Schema::Result::ArtistAward",
	{ "foreign.award_id" => "self.id" },
	{ cascade_copy => 0, cascade_delete => 0 },
);

sub src {
	return '/static/images/awards/' . shift->name . '.png';
}

sub type {
	(my $type = shift->name) =~ s/x\d+$//;

	return $type;
}

my %alt = (
	gold     => 'Gold medal',
	silver   => 'Silver medal',
	bronze   => 'Bronze medal',
	ribbon   => 'Participation ribbon',
	confetti => 'Most controversial',
	spoon    => 'Wooden spoon',
);

sub alt {
	return $alt{ shift->type } // 'Unknown';
}

1;
