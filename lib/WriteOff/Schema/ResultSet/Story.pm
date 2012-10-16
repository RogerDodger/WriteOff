package WriteOff::Schema::ResultSet::Story;

use strict;
use base 'WriteOff::Schema::ResultSet';

sub with_scores {
	my $self = shift;
	
	my $vote_rs = $self->result_source->schema->resultset('Vote');

	my $public = $vote_rs->public->search(
		{ 'public.story_id' => { '=' => { -ident => 'me.id' } } },
		{
			select => [{ avg => 'public.value' }],
			alias => 'public',
		}
	);
	
	my $private = $vote_rs->private->search(
		{ 'private.story_id' => { '=' => { -ident => 'me.id' } } },
		{
			select => [{ sum => 'private.value' }],
			alias => 'private',
		}
	);
	
	my $with_scores = $self->search_rs(undef, {
		'+select' => [
			{ '' => $public->as_query,  -as => 'public_score' },
			{ '' => $private->as_query, -as => 'private_score' },
		],
		'+as' => [ 'public_score', 'private_score' ],
		order_by => [
			{ -desc => 'private_score' },
			{ -desc => 'public_score' },
			{ -asc  => 'title' },
		],
	});
}

sub with_stats {
	my $self = shift;
	
	my @storys = $self->all;
	my $n = $#storys;
	
	for( my $i = 0; $i <= $n; $i++ ) {
		my $this = $storys[$i];
		my ($pos, $pos_low) = ($i, $i);
		
		$pos-- while $pos > 0 && $this == $storys[$pos-1];
		$this->{__pos} = $pos;
		
		$pos_low++ while $pos_low < $n && $this == $storys[$pos_low+1];
		$this->{__pos_low} = $pos_low;
		
		my (@votes, $sum) = $this->votes->public->get_column('value')->all;
		
		if( @votes ) {
			$sum += ($_ - $this->public_score) ** 2 for @votes;
			$this->{__stdev} = sqrt $sum / @votes;
		}
		else {
			$this->{__stdev} = 0;
		}
	}
	
	return @storys;
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