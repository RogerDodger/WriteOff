package WriteOff::Command::deploy;

use WriteOff::DateTime;
use WriteOff::Command;
use WriteOff::Schema;
use Crypt::URandom qw/urandom/;
use File::Spec;
use File::Copy qw/copy/;
use YAML qw/LoadFile/;

sub run {
	my $self = shift;
	my $yes = qr/^(?:y|yes)$/i;

	my $cfgfn = 'config.yml';
	my $home = '%WriteOff%';

	my $write_cfg = sub {
		say "+ create $home/$cfgfn";
		copy 'config-template.yml', $cfgfn;
	};

	my $write_secret = sub {
		my $secret = unpack "H*", urandom 16;
		open my $fh, ">>:encoding(UTF-8)", $cfgfn;
		say $fh "Plugin::Session:";
		say $fh "    storage_secret_key: $secret";
	};

	if (-e $cfgfn) {
		print "> $home/$cfgfn exists. Do you want to overwrite it? [y/N] ";
		chomp(my $ans = <STDIN>);
		if ($ans =~ $yes) {
			say "- unlink $home/$cfgfn";
			$write_cfg->();
		}

		my $cfg = LoadFile($cfgfn);
		if (!exists $cfg->{"Plugin::Session"}{storage_secret_key}) {
			$write_secret->();
		}
	}
	else {
		$write_cfg->();
		$write_secret->();
	}

	my $dbfn = 'data/WriteOff.db';

	my $write_db = sub {
		say "+ create $home/$dbfn";
		my $sch = WriteOff::Schema->connect("dbi:SQLite:$dbfn");
		$sch->deploy;
		$sch;
	};

	if (-e $dbfn) {
		print "> $home/$dbfn exists. Do you want to overwrite it? [y/N] ";
		chomp(my $ans = <STDIN>);
		if ($ans =~ $yes) {
			say "- unlink $home/$dbfn";
			unlink $dbfn;
			my $sch = $write_db->();

			$_ = $sch->resultset('EmailTrigger')->populate([
				[qw/name template prompt_in_subject/],
				['eventCreated', 'email/event-created.tt', 0],
				['promptSelected', 'email/prompt-selected.tt', 0],
				['votingStarted', 'email/voting-started.tt', 1],
				['resultsUp', 'email/results-up.tt', 1],
			]);

			$_ = $sch->resultset('Format')->populate([
				[qw/name wc_min wc_max/],
				['Short Story', 2000, 8000],
				['Minific', 400, 750],
			]);

			$_ = $sch->resultset('Genre')->populate([
				[qw/name descr created/],
				['Original', 'Fiction not dependent on work under U.S. copyright', DateTime->now],
			]);

			$_ = $sch->resultset('Artist')->populate([
				[qw/id name created updated/],
				[25, 'Anonymous', (DateTime->now) x 2],
			]);
		}
	}
	else {
		$write_db->();
	}

	say 'All done!';
}

'Construction complete';
