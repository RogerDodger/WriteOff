package WriteOff::Schema::ResultSet::Story;

use strict;
use base 'WriteOff::Schema::Item';

sub difficulty {
	shift->get_column('wordcount')->func_rs('sqrt')
	     ->get_column('wordcount')->func('avg');
}

sub metadata {
	return shift->search_rs(undef, {
		columns => [
			'id', 'user_id', 'event_id', 'ip',
			'title', 'artist_id', 'website', 'wordcount',
			'candidate', 'public_score', 'public_stdev',
			'finalist', 'private_score', 'rank', 'rank_low',
			'seed', 'created', 'updated'
		]
	});
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

sub gallery {
	return shift->order_by({ -desc => [qw/candidate seed/] })
}

sub recalc_candidates {
	my ($self, $work) = @_;

	$self->recalc_prelim_stats;

	my $w = 0;
	for my $story ($self->order_by({ -desc => 'prelim_score' })->all) {
		# TODO: change this to checking an assoc. prelim record's fillled status
		next if $story->author_vote_count < $story->author_story_count;

		$w += $work->{offset} + $story->wordcount / $work->{rate};
		$story->update({ candidate => 1 });

		last if $w >= $work->{threshold};
	}
}

sub recalc_controversial {
	my $self = shift;

	my $pre_min = $self->get_column('prelim_stdev')->min;
	my $pre_max = $self->get_column('prelim_stdev')->max;

	my $pub_min = $self->get_column('public_stdev')->min;
	my $pub_max = $self->get_column('public_stdev')->max;

	if (defined $pre_min) {
		$self->candidates->update({
			controversial => \qq{
				(public_stdev - $pub_min)/($pub_max - $pub_min)/2 +
				(prelim_stdev - $pre_min)/($pre_max - $pre_min)/2
			}
		});

		$self->noncandidates->update({
			controversial => \qq{
				(prelim_stdev - $pre_min)/($pre_max - $pre_min)
			}
		})
	}
	else {
		$self->update({
			controversial => \qq{
				(public_stdev - $pub_min)/($pub_max - $pub_min)
			}
		})
	}
}

sub recalc_prelim_stats {
	my $self = shift;

	my $votes = $self->result_source->schema->resultset('Vote');

	my $prelim_values = $votes->prelim->search(
		{ story_id => { '=' => { -ident => 'storys.id' } } },
		{ alias => 'inn' }
	)->get_column('value');

	$self->update({
		prelim_score => $prelim_values->func_rs('sum')->as_query,
		prelim_stdev => $prelim_values->func_rs('stdev')->as_query,
	})
}

sub recalc_private_stats {
	my $self = shift;
	my $votes = $self->result_source->schema->resultset('Vote');

	my $private_values = $votes->private->search(
		{ story_id => { '=' => { -ident => 'storys.id' } } },
		{ alias => 'inn' }
	)->get_column('value');

	$self->update({
		private_score => $private_values->func_rs('sum')->as_query,
	});
}

sub with_prelim_stats {
	my $self = shift;

	my $vote_rs = $self->result_source->schema->resultset('Vote');

	my $prelim = $vote_rs->prelim->search(
		{ story_id => { '=' => { -ident => 'me.id' } } },
		{ alias => 'prelim' }
	)->get_column('value')->sum_rs;

	my $record_rs = $self->result_source->schema->resultset('VoteRecord');

	my $author_vote_count = $record_rs->filled->prelim->search(
		{
			user_id  => { '=' => { -ident => 'me.user_id' } },
			event_id => { '=' => { -ident => 'me.event_id' } },
		},
		{
			group_by => 'record.id',
			alias => 'record',
		}
	)->count_rs;

	my $author_story_count = $self->search(
		{
			user_id  => { '=' => { -ident => 'me.user_id' } },
			event_id => { '=' => { -ident => 'me.event_id' } },
		},
		{ alias => 'storys' }
	)->count_rs;

	return $self->search_rs(undef, {
		'+select' => [
			{ '' => $prelim->as_query, -as => 'prelim_score' },
			{ '' => $author_vote_count->as_query, -as => 'author_vote_count' },
			{ '' => $author_story_count->as_query, -as => 'author_story_count' },
		],
		'+as' => [ 'prelim_score', 'author_vote_count', 'author_story_count' ]
	});
}

sub wordcount {
	my $self = shift;

	return $self->get_column('wordcount')->sum;
}

1;
