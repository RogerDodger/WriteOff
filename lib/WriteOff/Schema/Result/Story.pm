use utf8;
package WriteOff::Schema::Result::Story;

use strict;
use warnings;
use base "WriteOff::Schema::Result";

use overload (
	"==" => '_compare_scores',
	fallback => 1,
);

__PACKAGE__->table("storys");

__PACKAGE__->add_columns(
	"id",
	{ data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
	"event_id",
	{ data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
	"user_id",
	{ data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
	"ip",
	{ data_type => "text", is_nullable => 1 },
	"title",
	{ data_type => "text", is_nullable => 0 },
	"author",
	{ data_type => "text", default_value => "Anonymous", is_nullable => 0 },
	"website",
	{ data_type => "text", is_nullable => 1 },
	"contents",
	{ data_type => "text", is_nullable => 0 },
	"wordcount",
	{ data_type => "integer", is_nullable => 0 },
	"seed",
	{ data_type => "real", is_nullable => 1 },
	"views",
	{ data_type => "integer", default_value => 0, is_nullable => 1 },
	"finalist",
	{ data_type => "bit", default_value => 0, is_nullable => 0 },
	"candidate",
	{ data_type => "bit", default_value => 0, is_nullable => 0 },
	"public_score",
	{ data_type => "real", is_nullable => 0 },
	"public_stdev",
	{ data_type => "real", is_nullable => 0 },
	"private_score",
	{ data_type => "integer", is_nullable => 0 },
	"rank",
	{ data_type => "integer", is_nullable => 1 },
	"rank_low",
	{ data_type => "integer", is_nullable => 1 },
	"created",
	{ data_type => "timestamp", is_nullable => 1 },
	"updated",
	{ data_type => "timestamp", is_nullable => 1 },
);

__PACKAGE__->set_primary_key("id");

__PACKAGE__->belongs_to(
	"event",
	"WriteOff::Schema::Result::Event",
	{ id => "event_id" },
	{ is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);

__PACKAGE__->has_many(
	"image_stories",
	"WriteOff::Schema::Result::ImageStory",
	{ "foreign.story_id" => "self.id" },
	{ cascade_copy => 0, cascade_delete => 0 },
);

__PACKAGE__->has_many(
	"scores",
	"WriteOff::Schema::Result::Score",
	{ "foreign.story_id" => "self.id" },
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

__PACKAGE__->has_many(
	"votes",
	"WriteOff::Schema::Result::Vote",
	{ "foreign.story_id" => "self.id" },
	{ cascade_copy => 0, cascade_delete => 0 },
);

__PACKAGE__->many_to_many("images", "image_stories", "image");

__PACKAGE__->mk_group_accessors(
	column => 'prelim_score',
	column => 'author_vote_count',
	column => 'author_story_count',
);

sub type {
	return 'fic';
}

sub pos {
	return shift->rank;
}

sub pos_low {
	return shift->rank_low;
}

sub artist {
	return shift->author;
}

sub stdev {
	return shift->public_stdev;
}

sub _compare_scores {
	my ($left, $right) = @_;

	no warnings 'uninitialized';

	return $left->private_score == $right->private_score
	    && $left->public_score == $right->public_score;
}

sub final_score {
	return shift->public_score;
}

sub is_manipulable_by {
	my $self = shift;
	my $user = $self->result_source->schema->resultset('User')->resolve(shift)
		or return 0;

	return $user->is_admin
	    || $self->event->is_organised_by($user)
	    || $self->user_id == $user->id && $self->event->fic_subs_allowed;
}


sub id_uri {
	my $self = shift;
	require WriteOff::Util;

	return WriteOff::Util::simple_uri( $self->id, $self->title );
}

sub _is_public_candidate {
	my $self = shift;
	no warnings 'uninitialized';

	$self->prelim_score >= 0
	&& $self->author_vote_count >= $self->author_story_count
	# Legacy check. The above doesn't work on 'Sweet Music' data because some
	# of the participants don't have accounts on the site
	|| $self->votes->public->count;
}

1;
