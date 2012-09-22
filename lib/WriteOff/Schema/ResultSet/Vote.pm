package WriteOff::Schema::ResultSet::Vote;

use strict;
use base 'WriteOff::Schema::ResultSet';

=head2 average

Returns the average score in a set of votes.

Returns -2**31 if there are no votes in the resultset.

While returning undef would be more mathematically correct, undef equals 0 in a 
numeric sort, which would give undesirable results (undef should have a lower 
sort rank than a negative number).

Also, returning 'undef' would make the defined-or persistence in the image/story
rows not work.

=cut

sub average {
	my $self = shift;

	return -(1 << 31) if $self->count == 0;
	
	return $self->get_column('value')->sum / $self->count;
}

sub prelim {
	return shift->search(
		{ 'record.round' => 'prelim' }, 
		{ join => 'record' }
	);	
}

sub public {	
	return shift->search(
		{ 'record.round' => 'public' }, 
		{ join => 'record' }
	);
}

sub private {
	return shift->search(
		{ 'record.round' => 'private' }, 
		{ join => 'record' }
	);	
}

1;