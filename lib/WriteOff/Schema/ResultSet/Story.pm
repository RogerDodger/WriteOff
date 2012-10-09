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
			select => [{ avg => 'private.value' }],
			alias => 'private',
		}
	);
	
	my $prelim = $vote_rs->prelim->search(
		{ 'prelim.story_id' => { '=' => { -ident => 'me.id' } } },
		{
			select => [{ avg => 'prelim.value' }],
			alias => 'prelim',
		}
	);
	
	my $with_scores = $self->search_rs(undef, {
		'+select' => [
			{ '' => $public->as_query,  -as => 'public_score' },
			{ '' => $private->as_query, -as => 'private_score' },
			{ '' => $prelim->as_query,  -as => 'prelim_score' },
		],
		'+as' => [ 'public_score', 'private_score', 'prelim_score' ],
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
		
		my (@votes, $sum) = $this->votes->get_column('value')->all;
		$sum += ($_ - $this->public_score) ** 2 for @votes;
		$this->{__stdev} = sqrt $sum / @votes;
	}
	
	return @storys;
}

1;