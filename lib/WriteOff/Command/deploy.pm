package WriteOff::Command::deploy;

use WriteOff::Command;
use SQL::Script;
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
		my $script = SQL::Script->new;
		$script->read('data/schema/fresh.sql');
		$script->run($self->dbh);
	};

	if (-e $dbfn) {
		print "> `$dbfn` already exists. Do you want to overwrite it? [y/n] ";
		chomp(my $ans = <STDIN>);
		if ($ans =~ $yes) {
			say "- unlink $dbfn";
			unlink $dbfn;
			$write_db->();
		}
	}
	else {
		$write_db->();
	}

	say 'All done!';
}

'Construction complete';
