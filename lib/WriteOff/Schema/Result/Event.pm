use utf8;
package WriteOff::Schema::Result::Event;

use 5.01;
use strict;
use warnings;
use base "WriteOff::Schema::Result";

use WriteOff::Util qw/maybe simple_uri sorted/;
use WriteOff::Rank qw/twipie/;
use WriteOff::Award qw/MORTARBOARD/;
use List::Util ();

__PACKAGE__->table("events");

__PACKAGE__->add_columns(
	"id",
	{ data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
	"format_id",
	{ data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
	"genre_id",
	{ data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
	"last_post_id",
	{ data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
	"prompt",
	{ data_type => "text", default_value => "TBD", is_nullable => 0 },
	"blurb",
	{ data_type => "text", is_nullable => 1 },
	"wc_min",
	{ data_type => "integer", is_nullable => 1 },
	"wc_max",
	{ data_type => "integer", is_nullable => 1 },
	"content_level",
	{ data_type => "text", default_value => "T", is_nullable => 0 },
	"custom_rules",
	{ data_type => "text", is_nullable => 1 },
	"commenting",
	{ data_type => "bit", default_value => 1, is_nullable => 0 },
	"guessing",
	{ data_type => "bit", default_value => 1, is_nullable => 0 },
	"tallied",
	{ data_type => "bit", default_value => 0, is_nullable => 0 },
	"created",
	{ data_type => "timestamp", is_nullable => 1 },
	"updated",
	{ data_type => "timestamp", is_nullable => 1 },
);

__PACKAGE__->set_primary_key("id");


__PACKAGE__->has_many("ballots", "WriteOff::Schema::Result::Ballot", "event_id");
__PACKAGE__->has_many("entrys", "WriteOff::Schema::Result::Entry", "event_id");
__PACKAGE__->belongs_to("format", "WriteOff::Schema::Result::Format", "format_id");
__PACKAGE__->belongs_to("genre", "WriteOff::Schema::Result::Genre", "genre_id");
__PACKAGE__->belongs_to("last_post", "WriteOff::Schema::Result::Post", "last_post_id", { join_type => 'left' });
__PACKAGE__->has_many("posts", "WriteOff::Schema::Result::Post", "event_id");
__PACKAGE__->has_many("prompts", "WriteOff::Schema::Result::Prompt", "event_id");
__PACKAGE__->has_many("rounds", "WriteOff::Schema::Result::Round", "event_id");
__PACKAGE__->has_many("theorys", "WriteOff::Schema::Result::Theory", "event_id");
__PACKAGE__->has_many("user_events", "WriteOff::Schema::Result::UserEvent", "event_id");

__PACKAGE__->many_to_many(users => 'user_events', 'user');

sub storys {
	return shift->entrys->search({ story_id => { '!=' => undef }});
}

sub images {
	return shift->entrys->search({ image_id => { '!=' => undef }});
}

sub title {
	return shift->prompt;
}

sub start {
	my $round = shift->rounds->search(
		{ action => 'submit' },
		{ order_by => { -asc => 'start' } },
	)->first;

	$round && $round->start;
}

sub end {
	my $self = shift;

	$self->rounds->search({}, { order_by => { -desc => 'end' } })->first->end;
}

sub fic {
	Carp::croak "Deprecated round time `fic` called";
}

sub fic_end {
	Carp::croak "Deprecated round time `fic_end` called";
}

sub art {
	Carp::croak "Deprecated round time `art` called";
}

sub art_end {
	Carp::croak "Deprecated round time `art_end` called";
}

sub has {
	my $self = shift;
	return $self->rounds->search({ mode => shift, maybe action => shift })->count;
}

sub has_prompt {
	return shift->prompt_type;
}

sub has_started {
	my $self = shift;
	return sorted $self->start, $self->now_dt;
}

sub prompt_voting {
	shift->start->clone->subtract(days => 1);
}

sub has_results {
	my $self = shift;
	return $self->prelim || $self->public || $self->private;
}

sub now_dt {
	return shift->result_source->resultset->now_dt;
}

sub set_content_level {
	Carp::croak 'Deprecated function `set_content_level` called';
}

sub id_uri {
	my $self = shift;

	return $self->{__id_uri} //= simple_uri($self->id, $self->prompt);
}

sub organisers {
	my $self = shift;

	return $self->users->search({ role => 'organiser' }, {
		'+select' => [ \'role' ],
		'+as' => [ 'role' ],
	});
}

sub judges {
	my $self = shift;

	return $self->users->search({ role => 'judge' }, {
		'+select' => [ \'role' ],
		'+as' => [ 'role' ],
	});
}

sub is_organised_by {
	my $self = shift;
	my $user = $self->result_source->schema->resultset('User')->resolve(shift)
		or return 0;

	return $self->organisers->search({ id => $user->id })->count
	    || $user->is_admin;
}

sub prompt_subs_allowed {
	my $row = shift;
	return sorted $row->now_dt, $row->prompt_voting;
}

sub prompt_votes_allowed {
	my $row = shift;
	return sorted $row->prompt_voting, $row->now_dt, $row->start;
}

sub art_gallery_opens {
	my $self = shift;
	$self->has('art') && $self->rounds->art->submit->first->end_leeway;
}

sub fic_gallery_opens {
	my $self = shift;
	$self->has('fic') && $self->rounds->fic->submit->first->end_leeway;
}

sub art_subs_allowed {
	shift->rounds->art->submit->active(leeway => 1)->count;
}

sub fic_subs_allowed {
	shift->rounds->fic->submit->active(leeway => 1)->count;
}

sub art_gallery_opened {
	my $row = shift;
	return $row->has('art') && $row->art_gallery_opens <= $row->now_dt;
}

sub fic_gallery_opened {
	my $row = shift;
	return $row->has('fic') && $row->fic_gallery_opens <= $row->now_dt;
}

sub art_votes_allowed {
	my $row = shift;
	return sorted $row->art_end, $row->now_dt, $row->end;
}

sub prelim_votes_allowed {
	Carp::croak "Deprecated method 'prelim_votes_allowed' called";
}

sub public_votes_allowed {
	Carp::croak "Deprecated method 'public_votes_allowed' called";
}

sub private_votes_allowed {
	Carp::croak "Deprecated method 'private_votes_allowed' called";
}

sub author_guessing_allowed {
	my $row = shift;

	return $row->fic_gallery_opened && !$row->ended;
}

sub artist_guessing_allowed {
	my $row = shift;

	return $row->art_gallery_opened && !$row->ended;
}

sub ended {
	my $self = shift;

	$self->rounds->upcoming->count == 0 && $self->rounds->active == 0;
}

BEGIN { *is_ended = \&ended; }

sub timeline {
	[
		map {{
			name => $_->name,
			mode => $_->mode,
			action => $_->action,
			start => $_->start->iso8601,
			end => $_->end->iso8601,
		}}
		shift->rounds->search({ }, { order_by => 'start' })
	];
}

sub json {
	my $self = shift;

	my %data = (
		(map { $_ => $self->$_ } qw/id prompt wc_min wc_max content_level/),
		(map {
			$_ => {
				id => $self->$_->id,
				name => $self->$_->name,
			}
		} qw/format genre/),
		rounds => [
			map {{
				id => $_->id,
				name => $_->name,
				mode => $_->mode,
				action => $_->action,
				start => $_->start->iso8601,
				end => $_->end->iso8601,
			}} $self->rounds->search({}, { order_by => 'start' }),
		],
	);

	\%data;
}

sub reset_jobs {
	my $self = shift;

	my $rs = $self->result_source->schema->resultset('Job');

	# Remove old jobs
	$rs->search({
		action => { like => '/event/%' },
		-or => [
			{ args => '[' . $self->id . ']' },
			{ args => { like => '[' . $self->id . ',%' } }
		],
	})->delete;

	my @jobs = (
		{
			action => '/event/set_prompt',
			at => $self->start,
			args => [ $self->id ],
		},
		{
			action => '/event/check_rounds',
			at => $self->rounds->fic->submit->first->end_leeway,
			args => [ $self->id ],
		}
	);

	for my $round ($self->rounds->vote->all) {
		push @jobs, {
			action => '/event/tally_round',
			at => $round->end,
			args => [ $self->id, $round->id ],
		};
	}

	for my $job (@jobs) {
		next if $job->{at} < $self->now_dt;
		$rs->create($job);
	}
}

sub tally {
	my $self = shift;
	my $schema = $self->result_source->schema;
	my $entrys = $schema->resultset('Entry');
	my $storys = $self->storys->eligible;
	my $images = $self->images->eligible;
	my $rounds = $self->rounds->search({ action => 'vote' });

	# Apply decay to older events' scores;
	$entrys->decay($self->genre, $self->format, $self->id);

	$storys->tally($rounds->search_rs({ mode => 'fic' }));

	$self->theorys->process if $self->guessing;

	$self->update({ tallied => 1 });
}

sub students {
	my ($self, $mode) = @_;

	my $fk = { fic => 'story_id', art => 'image_id' }->{$mode}
		or die "Unknown mode $mode";

	return $self->result_source->schema->storage->dbh_do(
		sub {
			my ($storage, $dbh, @params) = @_;

			$dbh->selectall_hashref(qq{
				SELECT artist_id
				FROM entrys me
				WHERE event_id = ?
				AND 0 = (
					SELECT COUNT(*)
					FROM awards
					LEFT JOIN entrys ON awards.entry_id=entrys.id
					WHERE entrys.artist_id=me.artist_id
					AND awards.award_id=?
					AND entrys.$fk IS NOT NULL
				)
			}, 'artist_id', undef, @params);
		},
		$self->id, MORTARBOARD()->id
	);
}

sub uid {
	my ($self, $show_last_post) = @_;
	join '.', 'event-listing', $self->id, $show_last_post, $self->updated;
}

sub wordcount {
	shift->storys->related_resultset('story')->get_column('wordcount')->sum;
}

1;
