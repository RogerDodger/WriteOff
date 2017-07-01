package WriteOff::Schema::ResultSet::Theory;

use strict;
use warnings;
use base 'WriteOff::Schema::ResultSet';
use WriteOff::Award qw/:all/;

sub by {
	my ($self, $artist) = @_;

	$self->search({ artist_id => $artist });
}

sub by_rs {
	scalar shift->by(@_);
}

sub mode {
	my ($self, $mode) = @_;

	$self->search({ mode => $mode });
}

sub process {
	my $self = shift;

	my $best = 0;
	for my $theory ($self->all) {
		my $correct = 0;
		for my $guess ($theory->guesses->all) {
			$correct += $guess->artist_id == $guess->entry->artist_id;
		}
		$theory->update({ accuracy => $correct });
		$best = $correct if $correct > $best;
	}

	if ($best > 1) {
		$self->search({ accuracy => $best })->update({ award_id => SLEUTH()->id });
	}
}

1;
