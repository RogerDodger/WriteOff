use utf8;
package WriteOff::Schema::Result::Event;

use 5.01;
use strict;
use warnings;
use base "WriteOff::Schema::Result";

use WriteOff::Util qw/maybe simple_uri sorted/;
use WriteOff::Rank qw/twipie/;
require List::Util;

__PACKAGE__->table("events");

__PACKAGE__->add_columns(
	"id",
	{ data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
	"format_id",
	{ data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
	"genre_id",
	{ data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
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
		{ -or => [
			{ name => 'writing' },
			{ name => 'drawing' },
		]},
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

	return $row->art_gallery_opens <= $row->now_dt;
}

sub fic_gallery_opened {
	my $row = shift;

	return $row->fic_gallery_opens <= $row->now_dt;
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

sub public_label {
	my $self = shift;

	$self->private
		? $self->prelim
			? "Semifinals"
			: "Prelims"
		: "Finals";
}

sub timeline {
	[
		map {{
			name => $_->name,
			start => $_->start->iso8601,
			end => $_->end->iso8601,
		}}
		grep {
			# dont show art vote round in timeline for now
			$_->mode ne 'art' or $_->action ne 'vote'
		}
		shift->rounds->search({ }, { order_by => 'start' })
	];
}

sub reset_schedules {
	my $self = shift;

	my $rs = $self->result_source->schema->resultset('Schedule');

	# Remove old schedules
	$rs->search({
		action => { like => '/event/%' },
		-or => [
			{ args => '[' . $self->id . ']' },
			{ args => { like => '[' . $self->id . ',%' } }
		],
	})->delete;

	my @schedules = (
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
		push @schedules, {
			action => '/event/tally_round',
			at => $round->end,
			args => [ $self->id, $round->id ],
		};
	}

	for my $schedule (@schedules) {
		next if $schedule->{at} < $self->now_dt;
		$rs->create($schedule);
	}
}

sub _prelim_params {
	my ($self, $work) = @_;

	# Order by user_id so that initial seeding is faster
	my @storys = $self->storys->search(undef, {
		select       => [ 'id', 'wordcount', 'user_id' ],
		order_by     => 'user_id',
		result_class => 'DBIx::Class::ResultClass::HashRefInflator'
	})->all;

	my $w = 0;
	for my $story (@storys) {
		$w += $work->{offset} + $story->{wordcount} / $work->{rate};
	}

	my $x_len = int(0.5 +
		($work->{threshold} * $work->{prelim}) /
		($w / @storys)
	);

	return ($w, $x_len, @storys);
}

sub new_prelim_record_for {
	my ($self, $user, $work) = @_;
	my $schema = $self->result_source->schema;
	$user = $schema->resultset('User')->resolve($user) or return 0;

	my (undef, $size) = $self->_prelim_params($work);

	my $voted_storys = $schema->resultset('Vote')->search({
		"record.user_id"  => $user->id,
		"record.event_id" => $self->id,
		"record.round"    => 'prelim',
		"record.type"     => 'fic',
	}, { join => 'record' })->get_column('me.story_id');

	my $candidates = $self->storys->eligible->search({
		id      => { -not_in => $voted_storys->as_query },
		user_id => { '!=' => $user->id },
	});

	return "You've already voted on all the stories" if !$candidates->count;

	my $record = $self->create_related('vote_records', {
		user_id => $user->id,
		round   => 'prelim',
		type    => 'fic',
	});

	for (List::Util::shuffle $candidates->get_column('id')->all) {
		$record->create_related('votes', { story_id => $_ });
		last if --$size == 0;
	}

	0;
}

sub nuke_prelim_round {
	my $self = shift;
	return unless $self->prelim;

	$self->vote_records->search({ round => 'prelim' })->delete_all;

	my $public  = $self->prelim;
	my $private = $self->private && $self->public;
	my $end     = $self->private || $self->public;

	$self->update({
		prelim  => undef,
		public  => $public,
		private => $private,
		end     => $end,
	});

	$self->reset_schedules;

	$self->storys->update({ candidate => 1 });
}

=head2 prelim_distr

Distributes stories for preliminary voting.

Criteria: users do not get their own stories, and the standard deviation of the
judges' wordcounts is minimalised.

=cut

sub prelim_distr {
	my ($self, $work) = @_;

	my ($w, $x_len, @storys) = $self->_prelim_params($work);
	my $y_len = @storys;

	my %author_count; $author_count{$_}++ for map { $_->{user_id} } @storys;
	my $ac_mode = List::Util::max values %author_count;

	# If there aren't many entries, skip the prelim round
	if ($w < $work->{threshold} * 1.5 || $x_len >= $y_len - $ac_mode) {
		$self->nuke_prelim_round;
		return 0;
	}

	# System state array. First item is the judge.
	my @system = map { [ $_ ] } @storys;

	# Seed initial system.
	for my $col (0..$x_len-1) {
		for my $i (0..$y_len-1) {
			# Shift up by $ac_mode so that judges are not given their
			# own stories, and by $col so that there are no dupes in any set
			push $system[$i], $storys[ ($i + $ac_mode + $col) % $y_len ];
		}
	}

	my $check_system_constraints = sub {
		for my $row ( @system ) {
			my %uniq;
			for my $cell (@$row[1..$x_len]) {
				# Judges cannot have their own stories
				if ($cell->{user_id} == $row->[0]->{user_id}) {
					return 0;
				}

				# No dupes
				return 0 if exists $uniq{$cell->{id}};
				$uniq{$cell->{id}} = 1;
			}
		}
		1;
	};

	my $system_work = sub {
		my $work;

		for my $row ( @system ) {
			my $wc_total = List::Util::sum map { $_->{wordcount} } @$row[1 .. $x_len];
			$work += $wc_total * ( 1 + $wc_total ) / 2;
		}

		return $work;
	};

	my $system_stdev = sub {
		my @wcs = map {
			List::Util::sum map { $_->{wordcount} } @$_[1 .. $x_len]
		} @system;

		my $mean = List::Util::sum( @wcs ) / $y_len;

		my $variance;
		$variance += ($_ - $mean) ** 2 for @wcs;

		return sqrt $variance / $y_len;
	};

	my $cell_swap = sub {
		my ($c1, $c2) = @_;

		(
			$system[ $c1->{y} ][ $c1->{x} ],
			$system[ $c2->{y} ][ $c2->{x} ]
		) = (
			$system[ $c2->{y} ][ $c2->{x} ],
			$system[ $c1->{y} ][ $c1->{x} ]
		);
	};

	# Main algorithm. Take random cells and see if swapping them would decrease
	# the total work in the system.
	my $current_work = $system_work->();
	TICK: for (my $i = 0; $i <= 1000; $i++) {

		# Define two random cells to be swapped, with x in range (1..$x_len) so
		# that judges are never moved
		my $c1 = {
			x => int rand($x_len) + 1,
			y => int rand($y_len),
		};
		my $c2 = {
			x => int rand($x_len) + 1,
			y => int rand($y_len),
		};

		# No point swapping cells between the same judge
		redo if $c1->{y} == $c2->{y};

		my $item1 = $system[ $c1->{y} ][ $c1->{x} ];
		my $item2 = $system[ $c2->{y} ][ $c2->{x} ];

		# Don't give a judge their own story
		redo if $system[ $c1->{y} ][0]->{user_id} == $item2->{user_id};
		redo if $system[ $c2->{y} ][0]->{user_id} == $item1->{user_id};

		# Don't put an item in a set if it's already there
		for my $col (@{ $system[$c2->{y}] }) {
			redo TICK if $col->{id} == $item1->{id};
		}

		for my $col (@{ $system[$c1->{y}] }) {
			redo TICK if $col->{id} == $item2->{id};
		}

		# Swap cells and check if it's an improvement
		$cell_swap->($c1, $c2);
		my $new_work = $system_work->();

		if ($new_work < $current_work) {
			$i = 0;
			$current_work = $new_work;
		}
		else {
			$cell_swap->($c1, $c2);
		}
	}

	$self->result_source->schema->resultset('VoteRecord')->populate([ map {
		{
			event_id => $self->id,
			user_id  => $_->[0]->{user_id},
			round    => 'prelim',
			type     => 'fic',
			story_id => $_->[0]->{id},
			votes    => [ map {
				{ story_id => $_->{id} }
			} @$_[ 1..$x_len ] ],
		}
	} @system ]);

	1;
}

sub recalc_stats {
	my ($self, $items, $votes) = @_;

	my ($scores,$contr) = twipie($votes->slates);

	my $round = $votes->first->round;
	for my $item ($items->all) {
		$item->update({
			"${round}_score" => $scores->{$item->id} // 0,
			"${round}_stdev" => $contr->{$item->id} // 0,
		});
	}
}

=head2 public_distr

Determine candidates for public voting.

=cut

sub public_distr {
	my ($self, $work) = @_;

	$self->recalc_stats(
		scalar $self->storys->eligible,
		scalar $self->vote_records->prelim->fic
	);

	$self->storys->eligible->recalc_candidates($work);
}

=head2 judge_distr

Distributes stories for private voting.

=cut

sub judge_distr {
	my $self = shift;
	my $size = shift // 5;

	# Make sure the public_score column is up-to-date
	$self->storys->recalc_public_stats;

	my @storys = $self->storys->order_by({ -desc => 'public_score' })->all;
	my ($prev, $no_more_finalists);

	for my $story (@storys) {
		if ($no_more_finalists) {
			$story->update({ finalist => 0 });
			undef $story;
		}
		else {
			if (--$size < 0 || $story->public_score == $prev->public_score) {
				$story->update({ finalist => 1 });
			}
			else {
				$no_more_finalists = 1;
				redo;
			}
		}
		$prev = $story;
	}

	my $finalists = [ map {{ story_id => $_->id }}
	                    grep { defined $_ } @storys ];

	for my $judge ( $self->judges->all ) {
		my $record = $self->create_related('vote_records', {
			user_id => $judge->id,
			round   => 'private',
			type    => 'fic',
			votes   => $finalists,
		});
	}
}

sub tally {
	my $self = shift;
	my $schema = $self->result_source->schema;
	my $artists = $schema->resultset('Artist');
	my $scores = $schema->resultset('Score'); #TODO
	my $storys = $self->storys->eligible;
	my $images = $self->images->eligible;
	my $records = $self->vote_records;

	# Clean up possible old tallying
	$self->artist_awards->delete_all;
	$self->scores->delete_all;

	# Apply decay to older events' scores;
	$scores->decay;

	if ($self->prelim) {
		$self->recalc_stats($storys, scalar $records->prelim->fic);
	}

	if ($self->public) {
		$self->recalc_stats(scalar $storys->candidates, scalar $records->public->fic);
	}

	if ($self->private) {
		$self->recalc_stats(scalar $storys->finalists, scalar $records->private->fic);
	}

	$storys->recalc_rank;
	$artists->deal_awards_and_scores($storys);

	if ($self->art) {
		$self->recalc_stats($images, scalar $records->public->art);
		$images->recalc_rank;
		$artists->deal_awards_and_scores($images);
	}

	if ($self->guessing) {
		$records->guess->fic->process_guesses;
	}

	$artists->recalculate_scores;

	$self->update({ tallied => 1 });
}

1;
