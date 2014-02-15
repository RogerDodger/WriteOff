package WriteOff::Schema::ResultSet::Story;

use strict;
use base 'WriteOff::Schema::Item';

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
