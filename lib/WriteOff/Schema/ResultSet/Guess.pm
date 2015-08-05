package WriteOff::Schema::ResultSet::Guess;

use strict;
use base 'WriteOff::Schema::ResultSet';

sub correct {
	my $self = shift;
	my $first = $self->first or return $self;
	my $join = (grep { my $meth = "$_\_id"; $first->$meth } qw/image story/)[0];

	return $self if !$join;

	return $self->search_rs({
		"$join.artist_id" => { -ident => 'me.artist_id' },
	}, {
		join => $join,
		order_by => 'title',
	})
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
