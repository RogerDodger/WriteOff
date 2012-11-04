package WriteOff::Schema::ResultSet::Award;

use strict;
use base 'WriteOff::Schema::ResultSet';

my @medals = ( 'gold', 'silver', 'bronze' );

=head2 medal_for

Returns the medal for a given zero-based rank, or undef.

=cut

sub medal_for {
	my( $self, $rank ) = @_;
	
	return $self->find({ name => $medals[$rank] });
}

sub ordered {
	return shift->order_by( 'sort_rank' );
}

1;