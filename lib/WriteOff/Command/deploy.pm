package WriteOff::Command::deploy;

use DateTime;
use WriteOff::Command;
use WriteOff::Schema;
use File::Spec;
use File::Copy qw/copy/;

sub run {
	my $self = shift;
	my $yes = qr/^(?:y|yes)$/i;

	my $cfgfn = File::Spec->rel2abs('config.yml');

	my $write_cfg = sub {
		say "+ create $cfgfn";
		copy 'config-template.yml', $cfgfn;
	};

	if (-e $cfgfn) {
		print "> `$cfgfn` already exists. Do you want to overwrite it? [y/n] ";
		chomp(my $ans = <STDIN>);
		if ($ans =~ $yes) {
			say "- unlink $cfgfn";
			$write_cfg->();
		}
	}
	else {
		$write_cfg->();
	}

	my $dbfn = File::Spec->rel2abs('data/WriteOff.db');

	my $write_db = sub {
		say "+ create $dbfn";
		my $sch = WriteOff::Schema->connect("dbi:SQLite:$dbfn");
		$sch->deploy;
		$sch;
	};

	if (-e $dbfn) {
		print "> `$dbfn` already exists. Do you want to overwrite it? [y/n] ";
		chomp(my $ans = <STDIN>);
		if ($ans =~ $yes) {
			say "- unlink $dbfn";
			unlink $dbfn;
			my $sch = $write_db->();

			$sch->resultset('EmailTrigger')->populate([
				[qw/name template prompt_in_subject/],
				['eventCreated', 'email/event-created.tt', 0],
				['promptSelected', 'email/prompt-selected.tt', 0],
				['votingStarted', 'email/voting-started.tt', 1],
				['resultsUp', 'email/results-up.tt', 1],
			]);

			$sch->resultset('Format')->populate([
				[qw/name wc_min wc_max/],
				['Short Story', 2000, 8000],
				['Minific', 400, 750],
			]);

			$sch->resultset('Genre')->populate([
				[qw/name descr/],
				['Original', 'Fiction not dependent on work under U.S. copyright'],
			]);

			$sch->resultset('Artist')->populate([
				[qw/id name/],
				[25, 'Anonymous'],
			]);
		}
	}
	else {
		$write_db->();
	}

	say 'All done!';
}

'Construction complete';
