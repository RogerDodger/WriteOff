package WriteOff::Command::backup;

use WriteOff::Command;	
use DBI;
use File::Spec;
use POSIX 'strftime';
use IO::Compress::Gzip qw/gzip $GzipError/;

our $now = strftime('%Y-%m-%d', gmtime);

sub run {
	my ($self, $command, @args) = @_;

	if (defined $command && $command =~ /^(?:data|logs)$/) {
		$self->$command(@args);
	}
	else {
		$self->help;
	}
}

sub data {
	my $self = shift;

	my $dbname = "data/WriteOff.db";
	if (!-e $dbname) {
		say File::Spec->rel2abs($dbname) . " does not exist";
		exit(1);
	}
	my $dbh = $self->dbh();

	my $fn = "$dbname.$now";
	for (my $i = 0; -e $fn; $i++) { 
		$fn = "$dbname.$now.$i";
	}

	say "Backing up to $fn";
	$dbh->sqlite_backup_to_file($fn);

	if ($fn = shift) {
		die "$fn doesn't exist" unless -e $fn;
		say "Backing up from $fn";
		$dbh->sqlite_backup_from_file($fn);
	}
}

sub logs {
	for my $logfile (glob "log/*.log") {
		my $out = "$logfile.$now.gz";
		for (my $i = 0; -e $out; $i++) { 
			$out = "$logfile.$now.$i.gz";
		}

		gzip $logfile => $out
			or die "gzip failed: $GzipError\n";
		say "+ $logfile => $out";
		unlink $logfile;
	}
}

1;
