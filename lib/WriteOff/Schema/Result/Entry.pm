use utf8;
package WriteOff::Schema::Result::Entry;

use strict;
use warnings;
use base "WriteOff::Schema::Result";
require WriteOff::Util;

__PACKAGE__->table("entrys");

# The entry table has to have a copy of artist.user_id to account for when
# artist.name = "Anonymous". Otherwise, it isn't possible to determine the owner.

__PACKAGE__->add_columns(
	"id",
	{ data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
	"event_id",
	{ data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
	"user_id",
	{ data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
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
	"artist_public",
	{ data_type => "bit", default_value => 0, is_nullable => 0 },
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
__PACKAGE__->has_many("posts", "WriteOff::Schema::Result::Post", "entry_id");
__PACKAGE__->has_many("ratings", "WriteOff::Schema::Result::Rating", "entry_id");
__PACKAGE__->belongs_to("round", "WriteOff::Schema::Result::Round", "round_id", { join_type => 'left' });
__PACKAGE__->belongs_to("story", "WriteOff::Schema::Result::Story", "story_id");
__PACKAGE__->has_many("votes", "WriteOff::Schema::Result::Vote", "entry_id");
__PACKAGE__->belongs_to("user", "WriteOff::Schema::Result::User", "user_id");

__PACKAGE__->has_many('image_storys', "WriteOff::Schema::Result::ImageStory", { "foreign.image_id" => "self.image_id" });
__PACKAGE__->has_many('story_images', "WriteOff::Schema::Result::ImageStory", { "foreign.story_id" => "self.story_id" });

__PACKAGE__->mk_group_accessors(column => 'num');

sub awards_sorted {
	sort { $a->order <=> $b->order } shift->awards;
}

sub difficulty {
	my $self = shift;

	$self->story
		? $self->story->wordcount
		: 2500;
}

sub mode {
	my $self = shift;

	$self->image_id && 'pic' || 'fic';
}

sub view {
	"/" . shift->mode . "/view";
}

sub work {
	my ($self, $work) = @_;

	$self->story
		? $work->{offset} + $self->story->wordcount / $work->{rate}
		: $work->{offset};
}

BEGIN { *type = \&mode }

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

sub id_uri {
	my $self = shift;

	return WriteOff::Util::simple_uri($self->story_id || $self->image_id, $self->title);
}

sub detected {
	my $self = shift;

	return $self->guesses->search({ artist_id => $self->artist_id })->count;
}

sub pct {
	my $self = shift;

	return $self->{__pct} if exists $self->{__pct};

	$self->{__pct} = defined $self->rank
		? do {
			# If there is only 1 entry, then rank_low can be 0 and give a divide by zero error
			my $m = $self->event->entrys->mode($self->mode)->get_column('rank_low')->max;
			$m and 1 - $self->rank / $m;
		}
		: undef;
}

sub deadline {
	my $self = shift;

	# We're populating ->rounds with a prefetch. The grep here dodges hitting the DB again.
	$self->{__deadline} //=
		(grep { $_->mode eq $self->mode && $_->action eq 'submit' } $self->event->rounds)[-1]->end_leeway;
}

sub class { 'entry' }

1;
