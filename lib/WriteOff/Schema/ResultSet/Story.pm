package WriteOff::Schema::ResultSet::Story;

use strict;
use base 'WriteOff::Schema::ResultSet';
use Scalar::Util qw/looks_like_number/;

sub difficulty {
	shift->get_column('wordcount')->func_rs('sqrt')
	     ->get_column('wordcount')->func('avg');
}

sub metadata {
	return shift->search_rs(undef, {
		columns => [
			'id', 'user_id', 'event_id', 'ip',
			'title', 'artist_id', 'website', 'wordcount',
			'prelim_score', 'prelim_stdev',
			'candidate', 'public_score', 'public_stdev',
			'finalist', 'private_score', 'rank', 'rank_low',
			'controversial', 'seed', 'disqualified', 'created', 'updated',
		]
	});
}

sub finalists {
	return shift->search({ finalist => 1 });
}

sub order_by_score {
	return shift->order_by({ -desc => [ qw/private_score public_score prelim_score/ ]});
}

sub candidates {
	return shift->search({ candidate => 1 });
}

sub noncandidates {
	return shift->search({ candidate => 0 });
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

sub gallery {
	my ($self, $offset) = @_;

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
		order_by => [
			{ -asc => 'disqualified' },
			{ -desc => 'candidate' },
			{ -desc => 'seed' },
		],
	});
}

sub recalc_candidates {
	my ($self, $work) = @_;

	my $w = $work->{threshold} * 7;
	my @candidates;
	for my $story ($self->order_by({ -desc => 'prelim_score' })->all) {
		if ($w <= 0) {
			last if $candidates[-1]->prelim_score != $story->prelim_score;
		}

		$w -= $work->{offset} + $story->wordcount / $work->{rate};
		push @candidates, $story;
	}

	# We want to mark as candidates simultaneously. Using a transaction does
	# not guarantee a read does not occur intermittently, which could reveal
	# authors unintentionally (via fic/gallery.tt).
	$self->search({ id => { -in => [ map { $_->id } @candidates ] } })
	     ->update({ candidate => 1 });
}

sub wordcount {
	my $self = shift;

	return $self->get_column('wordcount')->sum;
}

1;
