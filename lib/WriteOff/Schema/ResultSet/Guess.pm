package WriteOff::Schema::ResultSet::Guess;

use strict;
use base 'WriteOff::Schema::ResultSet';

sub correct {
	shift->search_rs({
		"entry.artist_id" => { -ident => 'me.artist_id' },
	}, {
		join => 'entry',
		order_by => 'title',
	});
}

sub tally {
	my $self = shift;

	my %tally;
	$tally{$_->artist->name}++ for $self->search({}, { prefetch => 'artist' });

	return join ', ',
	         map { $tally{$_} == 1 ? $_ : "$_ ($tally{$_})" }
	           sort { $tally{$b} <=> $tally{$a} }
	             sort { lc $a <=> lc $b }
	               keys %tally;
}

1;
