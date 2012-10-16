package WriteOff::Schema::ResultSet::VoteRecord;

use strict;
use base 'WriteOff::Schema::ResultSet';

sub filled {
	return shift->search_rs(
		{ 'votes.value' => { '!=' => undef } },
		{ 
			join => 'votes',
			group_by => 'me.id',
		}
	);
}

sub unfilled {
	return shift->search_rs(
		{ 
			'votes.value' => undef, 
			'votes.id' => { '!=' => undef } 
		},
		{
			join => 'votes',
			group_by => 'me.id',
		}
	);
}

sub round {	
	return shift->search_rs({ round => shift });
}

sub prelim {
	return shift->round('prelim');
}

sub public {
	return shift->round('public');
}

sub private {
	return shift->round('private');
}

sub type {
	return shift->search_rs({ type => shift })
}

sub fic {
	return shift->type('fic');
}

sub art {
	return shift->type('art');
}

1;