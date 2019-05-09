package WriteOff::Command::round;

use WriteOff::Command;

can tally =>
	sub {
		my $r = shift;
		$r->tally;
		$r->update({ tallied => 1 });
	},
	which => q{
		Tallies round with id ROUND.
	};

1;
