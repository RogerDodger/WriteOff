use utf8;
package WriteOff::Schema::Result::Entry;

use strict;
use warnings;
use base "WriteOff::Schema::Result";
require WriteOff::Util;

__PACKAGE__->table("entrys");

__PACKAGE__->add_columns(
	"id",
	{ data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
	"event_id",
	{ data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
	"artist_id",
	{ data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
	"story_id",
	{ data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
	"image_id",
	{ data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
	"round_id",
	{ data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
	"title",
	{ data_type => "text", is_nullable => 0 },
	"seed",
	{ data_type => "real", is_nullable => 0, dynamic_default_on_create => sub { rand() } },
	"disqualified",
	{ data_type => 'bit', default_value => 0, is_nullable => 0 },
	"score",
	{ data_type => "real", is_nullable => 1 },
	"score_genre",
	{ data_type => "real", is_nullable => 1 },
	"score_format",
	{ data_type => "real", is_nullable => 1 },
	"rank",
	{ data_type => "integer", is_nullable => 1 },
	"rank_low",
	{ data_type => "integer", is_nullable => 1 },
	"views",
	{ data_type => "integer", default_value => 0, is_nullable => 1 },
	"created",
	{ data_type => "timestamp", is_nullable => 1 },
	"updated",
	{ data_type => "timestamp", is_nullable => 1 },
);

__PACKAGE__->set_primary_key("id");

__PACKAGE__->belongs_to("artist", "WriteOff::Schema::Result::Artist", "artist_id");
__PACKAGE__->has_many("awards", "WriteOff::Schema::Result::Award", "entry_id");
__PACKAGE__->belongs_to("event", "WriteOff::Schema::Result::Event", "event_id");
__PACKAGE__->has_many("guesses", "WriteOff::Schema::Result::Guess", "entry_id");
__PACKAGE__->belongs_to("image", "WriteOff::Schema::Result::Image", "image_id");
__PACKAGE__->has_many("ratings", "WriteOff::Schema::Result::Rating", "entry_id");
__PACKAGE__->belongs_to("round", "WriteOff::Schema::Result::Round", "round_id");
__PACKAGE__->belongs_to("story", "WriteOff::Schema::Result::Story", "story_id");
__PACKAGE__->has_many("votes", "WriteOff::Schema::Result::Vote", "entry_id");

__PACKAGE__->mk_group_accessors(column => 'num');

sub type {
	my $self = shift;

	$self->story_id && 'fic' ||
	$self->image_id && 'art';
}

sub item {
	my $self = shift;
	$self->story || $self->image;
}

sub item_id {
	my $self = shift;
	$self->story_id || $self->image_id;
}

sub pos {
	return shift->rank;
}

sub pos_low {
	return shift->rank_low;
}

# TODO: delete all this

sub _compare_scores {
	my ($left, $right) = @_;

	for my $round (qw/private public prelim/) {
		my $meth = "${round}_score";
		if (defined $left->$meth && defined $right->$meth) {
			return $left->$meth <=> $right->$meth;
		}
		elsif (defined $left->$meth) {
			return 1;
		}
		elsif (defined $right->$meth) {
			return -1;
		}
	}

	0;
}

sub score_totals {
	my $self = shift;

	return [
		($self->private_score) x!! $self->private_score,
		($self->public_score) x!! $self->public_score,
		($self->prelim_score / 10) x!! $self->prelim_score
	];
}

sub id_uri {
	my $self = shift;

	return WriteOff::Util::simple_uri($self->story_id || $self->image_id, $self->title);
}

sub detected {
	my $self = shift;

	return $self->guesses->search({ artist_id => $self->artist_id })->count;
}

1;
