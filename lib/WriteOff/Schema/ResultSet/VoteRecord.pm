package WriteOff::Schema::ResultSet::VoteRecord;

use strict;
use base 'WriteOff::Schema::ResultSet';

sub filled {
	my $self = shift;

	return $self->search(
		{ 'votes.value' => { '!=' => undef } },
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

sub story {
	my $self = shift;
	
	return $self;
}

1;