use utf8;
package WriteOff::Schema::Result::Round;

use 5.01;
use strict;
use warnings;
use base "WriteOff::Schema::Result";
require WriteOff::Util;
require WriteOff::Rank;

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

sub end_leeway {
	shift->end->clone->add(minutes => WriteOff::Util::LEEWAY);
}

sub tally {
	my ($self, $work) = @_;

	my ($scores,$errors) = WriteOff::Rank::twipie($self->ballots->slates);

	if ($self->ratings->count) {
		$self->ratings->delete;
	}

	for my $entry (keys $scores) {
		$self->create_related('ratings', {
			entry_id => $entry,
			value => $scores->{$entry},
			error => $errors->{$entry},
		});
	}

	my @ranking = reverse sort { $scores->{$a} <=> $scores->{$b} } keys %$scores;
	my @ranks = [ shift @ranking ];
	for my $entry (@ranking) {
		if ($scores->{$entry} == $scores->{$ranks[-1][0]}) {
			push @{ $ranks[-1] }, $entry;
		}
		else {
			push @ranks, [ $entry ];
		}
	}

	my $i = 0;
	my $entrys = $self->entrys;

	for my $rank (@ranks) {
		for my $entry (@$rank) {
			$entrys->find($entry)->update({
				rank     => $i,
				rank_low => $i + $#$rank,
			});
		}
		$i += @$rank;
	}

	# FIXME
	my $nextRound = $self->event->rounds->search({ name => 'final' })->first;

	my $w = $work->{threshold} * 5;
	my @cut;
	for my $entry ($entrys->order_by({ -asc => 'rank' })->all) {
		if ($w <= 0) {
			last if $cut[-1]->rank != $entry->rank;
		}

		$w -= $work->{offset} + $entry->story->wordcount / $work->{rate};
		push @cut, $entry;
	}

	$entrys->search({ id => { -in => [ map { $_->id } @cut ] } })
	       ->update({ round_id => $nextRound->id });

	$entrys->search({ id => { -not_in => [ map { $_->id } @cut ] } })
	       ->update({ artist_public => 1 });
}

1;
