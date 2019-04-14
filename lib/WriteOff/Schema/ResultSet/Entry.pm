package WriteOff::Schema::ResultSet::Entry;

use strict;
use warnings;
use base 'WriteOff::Schema::ResultSet';
use WriteOff::Award qw/:all/;
use WriteOff::Mode;
require List::Util;

sub artists_hash {
	my $self = shift;
	my %artists = map { $_->id => $_ } $self->related_resultset('artist')->all;
	\%artists;
}

sub eligible {
	shift->search({ disqualified => 0 });
}

sub difficulty {
	my $self = shift;
	my $n = $self->count or return;

	List::Util::sum(map { sqrt $_->difficulty } $self->all) / $n;
}

sub disqualified {
	shift->search({ disqualified => 1 });
}

sub gallery {
	my $self = shift;

	my $num_rs = $self->search(
		{
			event_id => { '=' => { -ident => 'me.event_id' }},
			seed => { '>' => { -ident => "me.seed" } },
		},
		{
			'select' => [ \'COUNT(*) + 1' ],
			'alias' => 'subq',
		}
	);

	$self->search({}, {
		'+select' => [ $num_rs->as_query ],
		'+as' => [ 'num' ],
		join => 'round',
		order_by => [
			{ -asc => 'disqualified' },
			{ -desc => 'round.end' },
			{ -desc => 'seed' },
		],
	});
}

sub mode {
	my ($self, $mode) = @_;

	$self->search({
		WriteOff::Mode->find($mode // 'fic')->fkey => { '!=' => undef }
	});
}

sub profile {
	shift->search(
		{
			'me.score' => { '!=' => undef },
			'me.artist_public' => 1,
		},
		{
			join => 'event',
			prefetch => [ 'awards', { event => [ 'rounds', 'entrys' ] } ],
			order_by => [
				{ -desc => 'event.created' },
				{ -desc => 'me.score' },
			],
		}
	);
}

sub profile_rs { scalar shift->profile }

sub popular {
	shift->profile->search({}, {
		order_by => { -desc => 'me.score' },
		rows => 10,
	});
}

sub popular_rs { scalar shift->popular }

sub public {
	shift->search({ artist_public => 1 });
}

sub public_rs { scalar shift->public }

sub rank_order {
	return shift->order_by({ -asc => [qw/rank title/] });
}

sub recalc_rank {
	my $self = shift;

	my @entrys = $self->all;
	my %ratings;
	for my $entry (@entrys) {
		$ratings{$entry->id} = [
			map { $_->value } $entry->ratings->search({}, {
				join => 'round',
				order_by => { -desc => 'round.end' },
			})
		];
	}

	my $cmp = sub {
		my ($l, $r) = @_;
		my @l = @{ $ratings{$l->id} };
		my @r = @{ $ratings{$r->id} };

		if (@l > @r) {
			return 1;
		}
		elsif (@r > @l) {
			return -1;
		}
		for my $i (0..$#l) {
			if ($l[$i] > $r[$i]) {
				return 1;
			}
			elsif ($r[$i] > $l[$i]) {
				return -1;
			}
		}
		return 0;
	};

	@entrys = sort $cmp @entrys;

	my @ranks = [ shift @entrys ];
	for my $entry (@entrys) {
		if ($cmp->($entry, $ranks[-1][0]) == 0) {
			push @{ $ranks[-1] }, $entry;
		}
		else {
			push @ranks, [ $entry ];
		}
	}

	my $i = 0;
	for my $rank (@ranks) {
		for my $entry (@$rank) {
			$entry->update({
				rank     => $i,
				rank_low => $i + $#$rank,
			});
		}
		$i += @$rank;
	}
}

sub sample {
	shift->search({}, {
		'+select', => [ \'COUNT(votes.value)' ],
		'+as' => [ 'priority' ],
		join => 'votes',
		group_by => 'me.id',
		order_by => [
			{ -asc => \'count(votes.value)' },
			{ -desc => \'RANDOM()' },
		],
	});
}

sub seed_order {
	return shift->order_by({ -desc => 'seed' });
}

1;
