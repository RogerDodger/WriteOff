package WriteOff::Schema::ResultSet::Artist;

use strict;
use base 'WriteOff::Schema::ResultSet';
use WriteOff::Award qw/:all/;

sub _award {
	my ($self, $rs, %p) = @_;

	my $type = $rs->first->type;
	my $colname = { fic => 'story_id', art => 'image_id' }->{$type};
	my %meta = (type => $type, event_id => $rs->first->event_id);

	my %artists;
	my %last;
	my @medals = ( GOLD, SILVER, BRONZE );

	my %mxstdv = (
		public => $rs->get_column('public_stdev')->max,
		prelim => $rs->get_column('prelim_stdev')->max,
	);
	my $n = $rs->count - 1;

	for my $item ($rs->rank_order->all) {
		my $aid = $item->artist_id;

		my @awards = (
			$mxstdv{prelim} && $item->prelim_stdev == $mxstdv{prelim} ? (CONFETTI) : (),
			$mxstdv{public} && $item->public_stdev == $mxstdv{public} ? (CONFETTI) : (),
		);

		if (!exists $artists{$aid}) {
			if (%last && $last{rank} == $item->rank) {
				push @awards, $last{medal};
				shift @medals;
			} elsif (@medals) {
				push @awards, shift @medals;
				%last = (rank => $item->rank, medal => $awards[-1]);
			} else {
				undef %last;
			}

			$artists{$aid} = [ [ $item, RIBBON ] ];
		}

		for my $award (@awards) {
			push @{ $artists{$aid} }, [ $item, $award ];
		}
	}

	while (my ($aid, $awards) = each %artists) {
		# Shift ribbon off
		if (@$awards != 1) {
			shift @$awards;
		}

		my $artist = $self->find($aid);
		for (@$awards) {
			my ($item, $award) = @$_;
			$artist->create_related('artist_awards', { %meta,
				$colname  => $item->id,
				award_id  => $award->id,
			});
		}
	}
}

sub _distr {
	my ($i, $n, $e) = @_;

	# bigger number -> more brutal curve
	$e //= 1.6;

	# simple exponential curve
	return (($n-$i)/($n+1))**$e;
}

sub _score {
	my ($self, $rs) = @_;

	my $type = $rs->first->type;
	my $colname = { fic => 'story_id', art => 'image_id' }->{$type};
	my %meta = (type => $type, event_id => $rs->first->event_id);

	# Multiply by 10 because whole numbers are nicer to display than
	# numbers with one decimal place
	my $D = $rs->difficulty * 10;

	my $n = $rs->count - 1;
	my %artists;
	for my $item ($rs->rank_order->all) {
		my $aid = $item->artist_id;

		my $score = $D * _distr(($item->rank + $item->rank_low) / 2, $n);

		if (exists $artists{$aid}) {
			# Additional entries have a small deduction
			$score -= $D * 0.2;
		}
		else {
			$artists{$aid} = 1;
		}

		$self->find($aid)->create_related('scores', { %meta,
			$colname => $item->id,
			value    => $score,
			orig     => $score,
		});
	}
}

sub deal_awards_and_scores {
	my ($self, $rs) = @_;
	return unless $rs->count;

	$self->_award($rs);
	$self->_score($rs);
}

sub recalculate_scores {
	my $self = shift;

	$self->result_source->schema->storage->dbh_do(sub {
		my ($storage, $dbh) = @_;

		$dbh->do(qq{
			UPDATE
				artists
			SET
				score =
					(SELECT SUM(value)
						FROM scores
						WHERE artist_id=artists.id);
		});
	});
}

1;
