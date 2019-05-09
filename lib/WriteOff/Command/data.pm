package WriteOff::Command::data;

use WriteOff::Command;
use DBI;
use File::Copy qw/copy/;
use POSIX 'strftime';
use IO::Compress::Gzip qw/gzip $GzipError/;
use Time::gmtime;
use Try::Tiny;

my $mt = gmtime;
my $day = 60 * 60 * 24;

my %ext = ( gzip => 'gz', lzma => 'lzma' );
my %compress = (
	gzip => sub {
		gzip $_[0] => "$_[0].gz" or die "gzip failed: $GzipError\n";
		unlink $_[0];
	},
	lzma => sub {
		{
			no warnings 'io';
			`lzma -V`;
			die "lzma not installed\n" if $?;
		}
		system("lzma -fz $_[0]") == 0 or die "\n";
	},
);

sub _copy {
	my ($in, $out) = @_;

	copy($in, $out);
	say STDERR "-> $out";
}

sub _rm {
	my $fn = shift;

	return if !-e $fn;
	unlink $fn;
	say STDERR "rm $fn";
}

sub _out {
	my $in = shift;
	my $now = shift // $mt;
	my $ts = strftime('%Y-%m-%d', @$now);

	return $in =~ s{^ (.+?) \. (.+) $}{$1-$ts.$2}rx;
}

sub _zip {
	my ($in, $alg) = @_;

	$compress{$alg}->($in);
	say STDERR "=> $in.$ext{$alg}";
}

can backup =>
	sub {
		my ($alg) = @_;

		my $in = "data/WriteOff.db";
		if (!-e $in) {
			say STDERR "$in does not exist";
			exit(1);
		}

		my $out = "data/today.db";
		dbh()->sqlite_backup_to_file($out);
		say STDERR "$in\n-> $out";

		if (defined $alg && exists $compress{$alg}) {
			try {
				_zip($out, $alg);
				$out = "$out.$ext{$alg}";
			}
			catch {
				print STDERR "Failed to compress: $_" if $_ ne "\n";
			}
		}

		# Extension of copies depends on compression type used, if any
		my $ext = $out =~ s/^ [^\.]+ \.//xr;

		# Backup policy:
		#   1. daily timestamped backup
		#   2. delete the timestamped backup from 3 days ago, except every 3 days
		#   3. delete the timestamped backup from 15 days ago
		#   4. never delete a timestamped backup landing on the 1st
		#
		# The consequence of this policy is that there should be backups of the 3
		# previous days, a backup from 6, 9, and 12 days ago, and a monthly backup.

		# (1)
		_copy($out, _out("data/WriteOff.$ext"));

		# (2)
		_rm(_out("data/WriteOff.$ext", gmtime(time - 3 * $day)))
			unless $mt->mday == 4 # (4)
			or (time / $day) % 3 == 0;

		# (3)
		_rm(_out("data/WriteOff.$ext", gmtime(time - 15 * $day)))
			unless $mt->mday == 16; # (4)
	},
	which => q{
		Copies the database to "today.db". Compresses this copy with ALG. Copies
		this file to a timestamped backup file. Deletes old backups such that there
		is a backup of the last 3 days; a backup from 6, 9, and 12 days ago; and a
		monthly backup.

		Valid values for ALG are "none", "gzip" and "lzma".
	},
	with => [
		alg => 'none',
	],
	fetch => 0;

can restore =>
	sub {
		my $fn = shift;

		abort qq{@{[ File::Spec->rel2abs($fn) ]} does not exist}
			if !-e $fn;

		say STDERR "Backing up from $fn";
		dbh()->sqlite_backup_from_file($fn);
	},
	which => q{
		Backs up the database from FILE, overwriting the live database.
	},
	with => [
		file => undef,
	],
	fetch => 0;


1;
