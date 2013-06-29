package WriteOff::Schema::ResultSet::Vote;

use strict;
use base 'WriteOff::Schema::ResultSet';

=head2 average

Returns the average score of a set of votes.

Returns -2**31 if there are no votes in the resultset.

While returning undef would be more mathematically correct, undef equals 0 in a
numeric sort, which would give undesirable results.

Also, returning undef would make the defined-or persistence in the image/story
rows not work.

=cut

sub average {
	my $self = shift->search({ value => { '!=' => undef } });

	return -(1 << 31) if $self->count == 0;
	
	return $self->get_column('value')->func('avg');
}

=head2 stdev

Returns the standard deviation of a set of votes.

Returns 0 if there are no votes in the resultset.

=cut

sub stdev {
	my $self = shift->search({ value => { '!=' => undef } });
	
	return 0 if $self->count == 0;
	
	my $mean = $self->average;
	
	my $sum;
	$sum += ($_ - $mean) ** 2 for $self->get_column('value')->all;
	
	return sqrt($sum / $self->count);
}

sub prelim {
	return shift->search_rs(
		{ 'record.round' => 'prelim' },
		{ join => 'record' }
	);	
}

sub public {	
	return shift->search_rs(
		{ 'record.round' => 'public' },
		{ join => 'record' }
	);
}

sub private {
	return shift->search_rs(
		{ 'record.round' => 'private' },
		{ join => 'record' }
	);	
}

1;