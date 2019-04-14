use utf8;
package WriteOff::Schema::Result::Round;

use 5.01;
use strict;
use warnings;
use base "WriteOff::Schema::Result";
use List::Util ();
use WriteOff::Util ();
use WriteOff::Rank ();
use WriteOff::DateTime;

__PACKAGE__->table("rounds");

__PACKAGE__->add_columns(
	"id",
	{ data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
	"event_id",
	{ data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
	"name",
	{ data_type => "text", is_nullable => 0 },
	"mode",
	{ data_type => "text", is_nullable => 0 },
	"action",
	{ data_type => "text", is_nullable => 0 },
	"tallied",
	{ data_type => "bit", is_nullable => 1 },
	"start",
	{ data_type => "timestamp", is_nullable => 0 },
	"end",
	{ data_type => "timestamp", is_nullable => 0 },
);

__PACKAGE__->set_primary_key("id");

__PACKAGE__->has_many("entrys", "WriteOff::Schema::Result::Entry", "round_id");
__PACKAGE__->belongs_to("event", "WriteOff::Schema::Result::Event", "event_id");
__PACKAGE__->has_many("ballots", "WriteOff::Schema::Result::Ballot", "round_id");
__PACKAGE__->has_many("ratings", "WriteOff::Schema::Result::Rating", "round_id");

sub active {
	my $self = shift;
	$self->start <= WriteOff::DateTime->now && !$self->finished;
}

sub days {
	my $self = shift;

	$self->end->delta_days($self->start)->in_units('days');
}

BEGIN { *duration = \&days };

sub end_leeway {
	shift->end->clone->add(minutes => WriteOff::Util::LEEWAY);
}

sub finished {
	shift->end <= WriteOff::DateTime->now;
}

sub slates {
	my $self = shift;

	# The voting algorithm receives only the slates as its input, which in the
	# case of entries that are in the round but received no votes means they'll
	# simply be returned a null score.

	# This is correct, since an entry with no votes does have an undefined score,
	# but this doesn't lead to desired behaviour. An undefined score will lead to
	# an undefined rank and no awards being given.

	# The two situations this can occur in are:

	# 1. An entry receives no votes because by happenstance nobody voted on it.
	# 2. There is only 1 entry in the event, so nobody could vote on it.

	# In the first circumstance, this isn't really a fair outcome, since it is
	# more likely than not that if the entry received at least 1 vote, it would
	# get more than 0 points, and the entrant is robbed of even a participation
	# ribbon.

	# The fairest outcome is to give it a score equal to chance. The ranking
	# algorithm does this to a reasonable approximation by giving it 1 win and 1
	# loss vs the imaginary team. This should lead to it getting a score of 1,
	# which should on average be a median score.

	# In the second circumstance, it's a little fairer since one could argue that
	# there is no competition with only 1 entry. Nonetheless, I think it's
	# preferable and congruent with the solution for the first circumstance for
	# this entry to get a gold medal. It will, however, still get a score of 0,
	# since the scoring algorithm gives last place 0 points.

	# To resolve this, then, we need to include every valid entry in an empty
	# slate. This is not the same as $self->entrys, since an entry's round_id is
	# the round it was eliminated in (or the final round if it's in that one).
	# Rather, we need to get the entrys whose round_id is in the set of rounds
	# including and after this one.
	my $rounds = $self->event->rounds->mode($self->mode)->vote->after_incl($self);
	my $entrys = $self->event->entrys->mode($self->mode)->eligible->search({
		round_id => { -in => $rounds->get_column('id')->as_query }
	});

	return [
		@{ $self->ballots->slates },
		map { [ $_->id ] } $entrys->all
	];
}

sub tally {
	my ($self, $work) = @_;
	my ($scores,$errors) = WriteOff::Rank::twipie($self->slates);

	if ($self->ratings->count) {
		$self->ratings->delete;
	}

	for my $entry (keys %$scores) {
		$self->create_related('ratings', {
			entry_id => $entry,
			value => $scores->{$entry},
			error => $errors->{$entry},
		});
	}

	my @ranking = reverse sort { $scores->{$a} <=> $scores->{$b} } keys %$scores;
	my @ranks = [ shift @ranking or () ];
	for my $entry (@ranking) {
		if ($scores->{$entry} == $scores->{$ranks[-1][0]}) {
			push @{ $ranks[-1] }, $entry;
		}
		else {
			push @ranks, [ $entry ];
		}
	}

	my $i = 0;
	my $entrys = $self->event->entrys->eligible->mode($self->mode);
	for my $rank (@ranks) {
		for my $entry (@$rank) {
			$entrys->find($entry)->update({
				rank     => $i,
				rank_low => $i + $#$rank,
			});
		}
		$i += @$rank;
	}

	my $rounds = $self->event->rounds->search({
		mode => $self->mode,
		action => $self->action,
	});

	if (my $nextRound = $rounds->after($self)->first) {
		my $wFinals = $work->{threshold} * 7;
		my $wTotal = List::Util::sum(map $_->work($work), $entrys->all);
		my $n = $rounds->count - 1;
		my $r = $rounds->before($self)->count + 1;

		# After $n cuts cutting $c entries, the finals should have $wFinals work
		# However, we should cut at least 50% of entries each round no matter what
		my $c = List::Util::min(0.5, ($wFinals / $wTotal) ** (1 / $n));
		my $w = $wTotal * $c**$r;

		my @cut;
		for my $entry ($entrys->order_by({ -asc => 'rank' })->all) {
			if ($w <= 0) {
				last if $cut[-1]->rank != $entry->rank;
			}

			$w -= $entry->work($work);
			push @cut, $entry;
		}

		$entrys->search({ id => { -in => [ map { $_->id } @cut ] } })
		       ->update({ round_id => $nextRound->id });

		$entrys->search({ id => { -not_in => [ map { $_->id } @cut ] } })
		       ->update({ artist_public => 1 });
	}
	else {
		$entrys->update({ artist_public => 1 });
	}
}

1;
