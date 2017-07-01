package WriteOff::Command::event;

use WriteOff::Command;
use Try::Tiny;
use IO::Prompt;
use HTML::Entities qw/decode_entities/;

sub run {
	my ($self, $command, @args) = @_;

	if (defined $command && $command =~ /^(?:schedule|score)$/) {
		$self->$command(@args);
	}
	else {
		$self->help;
	}
}

sub reset {
	my $self = shift;
	if (@_ < 1) {
		$self->help;
	}

	my $e = $self->db('Event')->find(shift);
	if (!defined $e) {
		say "Invalid event id";
		exit(1);
	}

	$e->reset_jobs;
}

sub score {
	my $self = shift;
	if (@_ < 1) {
		$self->help;
	}

	my $e = $self->db('Event')->find(shift);
	if (!defined $e) {
		say "Invalid event id";
		exit(1);
	}

	my $mode = WriteOff::Mode->find(shift // 'fic');

	$e->score($mode->name, decay => 0);
}

1;
