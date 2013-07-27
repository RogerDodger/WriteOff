use utf8;
package WriteOff::Schema::Result::Event;

use strict;
use warnings;
use base "WriteOff::Schema::Result";

use WriteOff::Util qw/simple_uri sorted/;
require List::Util;

__PACKAGE__->table("events");

__PACKAGE__->add_columns(
	"id",
	{ data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
	"prompt",
	{ data_type => "text", default_value => "TBD", is_nullable => 0 },
	"blurb",
	{ data_type => "text", is_nullable => 1 },
	"wc_min",
	{ data_type => "integer", is_nullable => 0 },
	"wc_max",
	{ data_type => "integer", is_nullable => 0 },
	"rule_set",
	{ data_type => "integer", default_value => 1, is_nullable => 0 },
	"custom_rules",
	{ data_type => "text", is_nullable => 1 },
	"start",
	{ data_type => "timestamp", is_nullable => 0 },
	"prompt_voting",
	{ data_type => "timestamp", is_nullable => 1 },
	"art",
	{ data_type => "timestamp", is_nullable => 1 },
	"art_end",
	{ data_type => "timestamp", is_nullable => 1 },
	"fic",
	{ data_type => "timestamp", is_nullable => 1 },
	"fic_end",
	{ data_type => "timestamp", is_nullable => 1 },
	"prelim",
	{ data_type => "timestamp", is_nullable => 1 },
	"public",
	{ data_type => "timestamp", is_nullable => 1 },
	"private",
	{ data_type => "timestamp", is_nullable => 1 },
	"end",
	{ data_type => "timestamp", is_nullable => 0 },
	"created",
	{ data_type => "timestamp", is_nullable => 1 },
);

__PACKAGE__->set_primary_key("id");

__PACKAGE__->has_many(
	"artist_awards",
	"WriteOff::Schema::Result::ArtistAward",
	{ "foreign.event_id" => "self.id" },
	{ cascade_copy => 0, cascade_delete => 0 },
);

__PACKAGE__->has_many(
	"images",
	"WriteOff::Schema::Result::Image",
	{ "foreign.event_id" => "self.id" },
	{ cascade_copy => 0, cascade_delete => 0 },
);

__PACKAGE__->has_many(
	"prompts",
	"WriteOff::Schema::Result::Prompt",
	{ "foreign.event_id" => "self.id" },
	{ cascade_copy => 0, cascade_delete => 0 },
);

__PACKAGE__->has_many(
	"scores",
	"WriteOff::Schema::Result::Score",
	{ "foreign.event_id" => "self.id" },
	{ cascade_copy => 0, cascade_delete => 0 },
);

__PACKAGE__->has_many(
	"storys",
	"WriteOff::Schema::Result::Story",
	{ "foreign.event_id" => "self.id" },
	{ cascade_copy => 0, cascade_delete => 0 },
);

__PACKAGE__->has_many(
	"user_events",
	"WriteOff::Schema::Result::UserEvent",
	{ "foreign.event_id" => "self.id" },
	{ cascade_copy => 0, cascade_delete => 0 },
);

__PACKAGE__->has_many(
	"vote_records",
	"WriteOff::Schema::Result::VoteRecord",
	{ "foreign.event_id" => "self.id" },
	{ cascade_copy => 0, cascade_delete => 0 },
);

__PACKAGE__->many_to_many(users => 'user_events', 'user');

sub title {
	return shift->prompt;
}

sub has_prompt {
	return shift->prompt_voting;
}

sub has_results {
	my $self = shift;
	return $self->prelim || $self->public || $self->private;
}

sub LEEWAY () {
	return 5; #minutes
}

sub now_dt {
	return shift->result_source->resultset->now_dt;
}

my %levels = (
	E => 0,
	T => 1,
	M => 2,
);

sub content_level {
	my $self = shift;

	$self->set_content_level(@_) if @_;

	return 'M' if $self->rule_set & 2;
	return 'T' if $self->rule_set & 1;
	return 'E';
}

sub set_content_level {
	my ( $self, $rating ) = @_;

	$self->update({ rule_set =>
		( ($self->rule_set // 0) & ~3) +
		$levels{$rating} // 0
	});
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

sub public_story_candidates {
	my $self = shift;

	return $self->storys->seed_order->all
		if !$self->prelim || $self->prelim_votes_allowed;

	# Doing the prelim_score search in the resultset doesn't work.
	# ...I don't know why, but I guess this'll do.
	#
	# Because you didn't put it in a HAVING statement, silly!!
	# --6 months later
	return grep {
		$_->_is_public_candidate
	} $self->storys->with_prelim_stats->seed_order->all;
}

sub public_story_noncandidates {
	my $self = shift;

	return () if !$self->prelim || $self->prelim_votes_allowed;

	return grep {
		!$_->_is_public_candidate
	} $self->storys->with_prelim_stats->seed_order->all;
}

sub storys_gallery_order {
	my $self = shift;

	return ( $self->public_story_candidates, $self->public_story_noncandidates );
}

sub prompt_subs_allowed {
	my $row = shift;

	return sorted $row->start, $row->now_dt, $row->prompt_voting;
}

sub prompt_votes_allowed {
	my $row = shift;

	return sorted $row->prompt_voting, $row->now_dt, $row->art || $row->fic;
}

sub art_gallery_opens {
	return shift->art_end->clone->add(minutes => LEEWAY);
}

sub fic_gallery_opens {
	return shift->fic_end->clone->add(minutes => LEEWAY);
}

sub art_subs_allowed {
	my $row = shift;

	return sorted $row->art, $row->now_dt, $row->art_gallery_opens;
}

sub fic_subs_allowed {
	my $row = shift;

	return sorted $row->fic, $row->now_dt, $row->fic_gallery_opens;
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
	my $row = shift;

	return $row->prelim && sorted $row->prelim, $row->now_dt, $row->public;
}

sub public_votes_allowed {
	my $row = shift;

	return sorted $row->public, $row->now_dt, $row->private || $row->end;
}

sub private_votes_allowed {
	my $row = shift;

	return $row->private && sorted $row->private, $row->now_dt, $row->end;
}

sub is_ended {
	my $row = shift;

	return $row->end <= $row->now_dt;
}

sub reset_schedules {
	my $self = shift;
	my @schedules;

	my $rs = $self->result_source->schema->resultset('Schedule');

	# Remove old schedules
	$rs->search({
		action => { like => '/event/%' },
		args   => '[' . $self->id . ']',
	})->delete;

	push @schedules, {
		action => '/event/set_prompt',
		at     => $self->art || $self->fic,
		args   => [ $self->id ],
	} if $self->has_prompt;

	push @schedules, {
		action => '/event/prelim_distr',
		at     => $self->prelim,
		args   => [ $self->id ],
	} if $self->prelim;

	push @schedules, {
		action => '/event/judge_distr',
		at     => $self->private,
		args   => [ $self->id ],
	} if $self->private;

	push @schedules, {
		action => '/event/tally_results',
		at     => $self->end,
		args   => [ $self->id ],
	} if $self->has_results;

	$rs->create($_) for grep { $_->{at} > $self->now_dt } @schedules;
}

sub new_prelim_record_for {
	my $self   = shift;
	my $schema = $self->result_source->schema;
	my $user   = $schema->resultset('User')->resolve(shift) or return 0;
	my $size   = shift // 6;

	my $voted_storys = $schema->resultset('Vote')->search({
		"record.user_id"  => $user->id,
		"record.event_id" => $self->id,
		"record.round"    => 'prelim',
		"record.type"     => 'fic',
	}, { join => 'record' })->get_column('me.story_id');

	my $candidates = $self->storys->search({
		id      => { -not_in => $voted_storys->as_query },
		user_id => { '!=' => $user->id },
	});

	return "You've already voted on all the stories" if !$candidates->count;

	my $record = $self->create_related('vote_records', {
		user_id => $user->id,
		round   => 'prelim',
		type    => 'fic',
	});

	for( List::Util::shuffle $candidates->get_column('id')->all ) {
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
}

=head2 judge_distr

Distributes stories for private voting.

=cut

sub judge_distr {
	my $self = shift;
	my $size = shift // 5;

	my @storys = $self->storys->with_scores->order_by({ -desc => 'public_score' })->all;

	my $no_more_finalists = 0;
	for( my $i = 0; $i <= $#storys; $i++ ) {
		my ($story, $prev) = @storys[$i, $i-1];

		if( $no_more_finalists ) {
			$story->update({ is_finalist => 0 });
			undef $storys[$i];
		}
		else {
			if($i < $size || $story->public_score == $prev->public_score) {
				$story->update({ is_finalist => 1 });
			}
			else {
				$no_more_finalists = 1;
				redo;
			}
		}
	}

	my @finalist_ids = map { $_->id } grep { defined $_ } @storys;

	for my $judge ( $self->judges->all ) {
		my $record = $self->create_related('vote_records', {
			user_id => $judge->id,
			round   => 'private',
			type    => 'fic',
			votes   => [
				map {
					{ story_id => $_ }
				} @finalist_ids
			]
		});
	}
}

=head2 prelim_distr

Distributes stories for preliminary voting.

Criteria: users do not get their own stories, and the standard deviation of the
judges' wordcounts is minimalised.

=cut

sub prelim_distr {
	my $self = shift;
	my $x_len = shift // 6;
	my $y_len = $self->storys->count;

	# Order by user_id so that initial seeding is faster
	my @storys = $self->storys->search(undef, {
		select       => [ 'id', 'wordcount', 'user_id' ],
		order_by     => 'user_id',
		result_class => 'DBIx::Class::ResultClass::HashRefInflator'
	})->all;

	my %author_count; $author_count{$_}++ for map { $_->{user_id} } @storys;
	my $mode_count = List::Util::max values %author_count;

	# No point doing prelim round with so few stories
	#
	# Also, the algo will loop forever trying to find a valid cell to swap
	# with if `$x_len >= $y_len - $mode_count`
	if( $x_len >= $y_len - $mode_count ) {
		$self->nuke_prelim_round;
		return 0;
	}

	# System state array. First item is the judge.
	my @system = map { [ $_ ] } @storys;

	# Seed initial system.
	for( my $col = 0; $col < $x_len; $col++ ) {
		for( my $i = 0; $i < $y_len; $i++ ) {
			# Shift up by $mode_count so that judges are not given their
			# own stories, and by $col so that there are no dupes in any set
			push $system[$i], $storys[ ($i + $mode_count + $col) % $y_len ];
		}
	}

	my $check_system_constraints = sub {
		for my $row ( @system ) {
			# Judges cannot have their own stories
			return 0 if $row->[0]->{user_id} ~~ [ map { $_->{user_id} } @$row[1 .. $x_len] ];

			# No dupes
			my %story_count; $story_count{$_}++ for map { $_->{id} } @$row;
			return 0 unless List::Util::max( values %story_count ) == 1;
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
		my( $c1, $c2 ) = @_;

		my $temp = $system[ $c1->{y} ][ $c1->{x} ];

		$system[ $c1->{y} ][ $c1->{x} ] = $system[ $c2->{y} ][ $c2->{x} ];

		$system[ $c2->{y} ][ $c2->{x} ] = $temp;
	};

	# Main algorithm. Take random cells and see if swapping them would decrease
	# the total work in the system.
	my $current_work = $system_work->();
	for( my $i = 0; $i <= 1000; $i++ ) {

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
		redo if $item1->{id} ~~ [ map { $_->{id} } @{ $system[ $c2->{y} ] } ];
		redo if $item2->{id} ~~ [ map { $_->{id} } @{ $system[ $c1->{y} ] } ];

		$cell_swap->( $c1, $c2 );
		my $new_work = $system_work->();

		if( $new_work < $current_work ) {
			$i = 0;
			$current_work = $new_work;
		}
		else {
			$cell_swap->( $c1, $c2 );
		}
	}

	$self->result_source->schema->resultset('VoteRecord')->populate([ map {
		{
			event_id => $self->id,
			user_id  => $_->[0]->{user_id},
			round    => 'prelim',
			type     => 'fic',
			votes    => [ map {
				{ story_id => $_->{id} }
			} @$_[ 1..$x_len ] ],
		}
	} @system ]);

	1;
}


1;
