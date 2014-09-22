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
			'title', 'author', 'website', 'wordcount',
			'candidate', 'public_score', 'public_stdev',
			'finalist', 'private_score', 'rank', 'rank_low',
			'seed', 'created', 'updated'
		]
	});
}

sub order_by_score {
	return shift->order_by({ -desc => [ qw/private_score public_score/ ]});
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
	my $self = shift;

	$self->update({
		candidate => \q{
				(SELECT COUNT(prelim) FROM events e WHERE e.id = event_id) = 0
			OR
				(SELECT COUNT(*) FROM vote_records r
					WHERE r.event_id = storys.event_id
					AND round = 'prelim'
					AND type = 'fic'
					AND filled = 1) >=
				(SELECT COUNT(*) FROM storys inn
					WHERE storys.user_id = inn.user_id
					AND storys.event_id = inn.event_id)
			AND
				(SELECT SUM(v.value) FROM votes v, vote_records r
					WHERE v.record_id = r.id
					AND r.round = 'prelim'
					AND v.story_id = storys.id) >= 0
		},
	});
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
