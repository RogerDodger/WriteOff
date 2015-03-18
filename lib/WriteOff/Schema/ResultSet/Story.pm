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
			'prelim_score', 'prelim_stdev',
			'candidate', 'public_score', 'public_stdev',
			'finalist', 'private_score', 'rank', 'rank_low',
			'controversial', 'seed', 'created', 'updated',
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
	my ($self, $offset) = @_;

	shift->metadata->order_by([
		{ -desc => 'candidate' },
		{ -desc => \qq{ seed+$offset - floor(seed+$offset) } },
	]);
}

sub recalc_candidates {
	my ($self, $work) = @_;

	$self->recalc_prelim_stats;

	my $w = 0;
	my @ids;
	for my $story ($self->order_by({ -desc => 'prelim_score' })->all) {
		if ($story->vote_records->count != 1) {
			Carp::croak "Story $story->id bad record count";
		}

		next if !$story->vote_records->single->filled;

		$w += $work->{offset} + $story->wordcount / $work->{rate};
		push @ids, $story->id;

		last if $w >= $work->{threshold};
	}

	$self->search({ id => { -in => \@ids } })->update({ candidate => 1 });
}

sub recalc_controversial {
	my $self = shift;

	my $votes = $self->result_source->schema->resultset('Vote');

	my $values = $votes->search(
		{ "inn.story_id" => { '=' => { -ident => 'storys.id' } } },
		{ alias => 'inn' }
	)->get_column('percentile');

	$self->update({ controversial => $values->func_rs('stdev')->as_query });
	$self->update({ controversial => \qq{ controversial / 10.0 } });
}

sub recalc_prelim_stats {
	my $self = shift;

	my $votes = $self->result_source->schema->resultset('Vote');

	my $prelim_values = $votes->prelim->search(
		{ "inn.story_id" => { '=' => { -ident => 'storys.id' } } },
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
		{ "inn.story_id" => { '=' => { -ident => 'storys.id' } } },
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
