use utf8;
package WriteOff::Schema::Result::Theory;

use strict;
use warnings;
use base "WriteOff::Schema::Result";
use Class::Null;
use WriteOff::Award;

__PACKAGE__->table("theorys");

__PACKAGE__->add_columns(
	"id",
	{ data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
	"event_id",
	{ data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
	"mode",
	{ data_type => "text", is_nullable => 0 },
	"user_id",
	{ data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
	"artist_id",
	{ data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
	"award_id",
	{ data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
	"accuracy",
	{ data_type => "integer", is_nullable => 1 },
	"created",
	{ data_type => "timestamp", is_nullable => 1 },
	"updated",
	{ data_type => "timestamp", is_nullable => 1 },
);

__PACKAGE__->set_primary_key("id");

__PACKAGE__->belongs_to("artist", "WriteOff::Schema::Result::Artist", "artist_id");
__PACKAGE__->belongs_to("event", "WriteOff::Schema::Result::Event", "event_id");
__PACKAGE__->belongs_to("user", "WriteOff::Schema::Result::User", "user_id");
__PACKAGE__->has_many("guesses", "WriteOff::Schema::Result::Guess", "theory_id");

sub award {
	my $self = shift;

	$self->award_id && WriteOff::Award->new($self->award_id);
}

1;
