package WriteOff::Command::round;

use WriteOff::Command;

sub _find {
	my $self = shift;
	if (@_ < 1) {
		$self->help;
	}

	my $r = $self->db('Round')->find(shift);
	if (!defined $r) {
		say "Invalid round id";
		exit(1);
	}

	$r;
}

sub tally {
	my $self = shift;
	my $r = $self->_find(shift);
	$r->tally;
	$r->update({ tallied => 1 });
}

1;
