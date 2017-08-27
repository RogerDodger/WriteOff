package WriteOff::Command::restore;

use WriteOff::Command;

sub data {
	my ($self, $fn) = @_;

	if (@_ < 2) {
		$self->help;
	}

	if (!-e $fn) {
		say File::Spec->rel2abs($fn) . " does not exist";
		exit(1);
	}

	say "Backing up from '$fn'";
	$self->dbh->sqlite_backup_from_file($fn);
}

1;
