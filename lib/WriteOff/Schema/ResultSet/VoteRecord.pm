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
	my( $self, $round ) = @_;
	
	return scalar $self->search({ round => $round });
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