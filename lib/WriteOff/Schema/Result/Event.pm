use utf8;
package WriteOff::Schema::Result::Event;

use 5.01;
use strict;
use warnings;
use base "WriteOff::Schema::Result";

use WriteOff::Util qw/maybe simple_uri sorted/;
use WriteOff::Rank qw/twipie/;
use WriteOff::Award qw/:all/;
use WriteOff::Mode qw/:all/;
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
	"prompt_fixed",
	{ data_type => "text", is_nullable => 1 },
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


__PACKAGE__->has_many("artist_events", "WriteOff::Schema::Result::ArtistEvent", "event_id");
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
__PACKAGE__->many_to_many(artists => 'artist_events', 'artist');

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

sub pic {
	Carp::croak "Deprecated round time `pic` called";
}

sub pic_end {
	Carp::croak "Deprecated round time `pic_end` called";
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

BEGIN { *started = \&has_started }

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

	return $self->artists->search({ role => 'organiser' }, {
		'+select' => [ \'role' ],
		'+as' => [ 'role' ],
	});
}

sub judges {
	my $self = shift;

	return $self->artists->search({ role => 'judge' }, {
		'+select' => [ \'role' ],
		'+as' => [ 'role' ],
	});
}

sub is_organised_by {
	my $self = shift;
	my $user = $self->result_source->schema->resultset('User')->resolve(shift)
		or return 0;

	return $self->organisers->search({ id => $user->active_artist_id })->count
	    || $user->is_admin;
}

sub is_judged_by {
	my $self = shift;
	my $user = $self->result_source->schema->resultset('User')->resolve(shift)
		or return 0;

	return $self->judges->search({ id => $user->active_artist_id })->count;
}

sub prompt_subs_allowed {
	my $row = shift;
	return sorted $row->now_dt, $row->prompt_voting;
}

sub prompt_votes_allowed {
	my $row = shift;
	return sorted $row->prompt_voting, $row->now_dt, $row->start;
}

sub pic_gallery_opens {
	my $self = shift;
	$self->has('pic') && $self->rounds->pic->submit->first->end_leeway;
}

sub fic_gallery_opens {
	my $self = shift;
	$self->has('fic') && $self->rounds->fic->submit->first->end_leeway;
}

sub pic_subs_allowed {
	shift->rounds->pic->submit->active(leeway => 1)->count;
}

sub fic_subs_allowed {
	shift->rounds->fic->submit->active(leeway => 1)->count;
}

sub pic_gallery_opened {
	my $row = shift;
	return $row->has('pic') && $row->pic_gallery_opens <= $row->now_dt;
}

sub fic_gallery_opened {
	my $row = shift;
	return $row->has('fic') && $row->fic_gallery_opens <= $row->now_dt;
}

sub pic_votes_allowed {
	my $row = shift;
	return sorted $row->pic_end, $row->now_dt, $row->end;
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

	return $row->pic_gallery_opened && !$row->ended;
}

sub rorder {
	my $self = shift;

	$self->{__rorder} //= WriteOff::Util::rorder($self->rounds_rs);
}

sub fic2pic {
	shift->rorder eq 'fic2pic';
}

sub pic2fic {
	shift->rorder eq 'pic2fic';
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
		shift->rounds->search({ }, { order_by => 'end' })
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

sub score {
	my ($self, $mode, %opt) = @_;

	$mode = WriteOff::Mode->find($mode // 'fic');
	$opt{decay} //= 1;
	$opt{award} //= 1;
	$opt{score} //= 1;

	my $schema = $self->result_source->schema;
	my $entrys = $self->entrys->search({
		$mode->fkey => { '!=' => undef },
		rank        => { '!=' => undef },
		rank_low    => { '!=' => undef },
	});

	Carp::croak sprintf "No %s entries for %s\n", $mode->name, $self->id_uri
		if !$entrys->count;

	# Apply decay to older events' scores
	if ($opt{decay}) {
		my $scores = $schema->resultset('Entry')->search(
			{
				score => { '!=' => undef },
				$mode->fkey => { '!=' => undef },
			},
			{ join => 'event' },
		);

		my $gScores = $scores->search({ genre_id => $self->genre_id });
		$gScores->update({ score_genre => \q{score_genre * 0.9} });

		my $fScores = $gScores->search({ format_id => $self->format_id });
		$fScores->update({ score_format => \q{score_format * 0.9} });
	}

	# Assign awards to the entries
	if ($opt{award}) {
		# In case this sub is re-run, clear awards previous assigned
		$entrys->related_resultset('awards')->delete;

		my $rounds = $self->rounds->search({
			action => 'vote',
			mode => $mode->name
		});

		my %aawards;
		my %last;
		my @medals = ( GOLD, SILVER, BRONZE );
		my %students = %{ $self->students($mode->name) };
		my $graduate;

		my %rels;
		my $mxrel;
		if ($mode->is(PIC) && $self->pic2fic || $mode->is(FIC) && $self->fic2pic) {
			# TODO: Trying to optimise this with a prefetch gives "ambiguous
			# column image_id" error. Not really that important since this
			# function runs like once a month
			my $meth = $mode->is(FIC) ? 'story_images' : 'image_storys';
			%rels = map { $_->id => $_->$meth->count } $entrys->all;
			$mxrel = List::Util::max values %rels;
		}
		my %mxerr = map { $_->id => $_->ratings->get_column('error')->max } $rounds->all;

		for my $entry ($entrys->rank_order->all) {
			my $aid = $entry->artist_id;
			my @awards;

			if (defined $mxrel and $rels{$entry->id} == $mxrel) {
				push @awards, LIGHTBULB();
			}

			for my $rating ($entry->ratings) {
				if ($mxerr{$rating->round_id} == $rating->error) {
					push @awards, CONFETTI();
				}
			}

			if ($students{$aid}) {
				# Have to consider the case where two "students" tie and both get
				# a mortarboard. Otherwise, only the first student gets one.
				if (!defined $graduate || $graduate == $entry->rank) {
					push @awards, MORTARBOARD();
					$graduate = $entry->rank;
				}
			}

			if (!exists $aawards{$aid}) {
				# Artists can only get one medal, so the medal check only
				# happens if this artist hasn't been passed yet
				if (%last && $last{rank} == $entry->rank) {
					push @awards, $last{medal};
					shift @medals;
				} elsif (@medals) {
					push @awards, shift @medals;
					%last = (rank => $entry->rank, medal => $awards[-1]);
				} else {
					undef %last;
				}

				$aawards{$aid} = [ [ $entry, RIBBON ] ];
			}

			for my $award (@awards) {
				push @{ $aawards{$aid} }, [ $entry, $award ];
			}
		}

		for my $awards (values %aawards) {
			# Shift off ribbon if artist has >1 award
			if (@$awards != 1) {
				shift @$awards;
			}
		}

		$schema->resultset('Award')->populate([
			map {
				map {{
					entry_id => $_->[0]->id,
					award_id => $_->[1]->id,
				}} @$_
			} values %aawards
		]);
	}

	# Assign scores to the entries
	if ($opt{score}) {
		# Multiply by 10 because whole numbers are nicer to display than
		# numbers with one decimal place
		my $D = $entrys->difficulty * 10;

		my $max = $entrys->get_column('rank_low')->max;
		my %seen;
		for my $entry ($entrys->rank_order->all) {
			my $aid = $entry->artist_id;

			my $pos = ($entry->rank + $entry->rank_low) / 2;
			my $pct = 1 - ($pos + 1) / ($max + 1);
			my $score = $D * $pct ** 1.6;

			if (exists $seen{$aid}) {
				# Additional entries have a small penalty
				$score -= $D * 0.2;
			}
			else {
				$seen{$aid} = 1;
			}

			$entry->update({
				score => $score,
				score_format => $score,
				score_genre => $score,
			});
		}
	}

	$self->update({ tallied => 1 });
}

sub students {
	my ($self, $mode) = @_;

	my $fk = WriteOff::Mode->find($mode)->fkey;

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

sub calibrate {
	my ($self, $work) = @_;

	my $rounds = $self->rounds->fic->vote;
	my $entrys = $self->storys;
	my $n = $rounds->count - 1;

	my $wFinals = $work->{threshold} * $rounds->search({ name => 'final' })->first->days;
	my $wTotal = List::Util::sum(map $_->work($work), $entrys->all);

	# After $n cuts cutting $c entries, the finals should have $wFinals work,
	# i.e., $wT * $c ** $n = $wF
	#
	# We want to cut at least 1/3 of the entries per round, so find $n when $c
	# = 0.66
	my $c = 0.66;
	my $maxN = (log($wFinals) - log($wTotal)) / log($c);
	printf "%f * $c ** %f = %f\n", $wTotal, $maxN, $wFinals if $ENV{WRITEOFF_DEBUG};

	# Delete $d rounds
	my $d = $n - List::Util::max(0, int $maxN);
	my @rounds = reverse $rounds->ordered->all;

	if (!$ENV{WRITEOFF_DEBUG}) {
		# Don't calibrate if a round has already been tallied
		return if $rounds->search({ tallied => 1 })->count;

		$self->result_source->schema->storage->dbh_do(
			sub {
				my ($storage, $dbh) = @_;

				# TODO: fix schema so this isn't necessary
				$dbh->do(q{ PRAGMA foreign_keys = 'OFF' });

				for (1..$d) {
					for my $i (0..$#rounds-1) {
						$rounds[$i + 1]->update({
							name => $rounds[$i]->name,
							end => $rounds[$i]->end,
						});
					}

					$rounds[0]->delete;
					shift @rounds;
				}

			},
		);

		if ($d > 0) {
			$self->reset_jobs;
		}
	}

}

1;
