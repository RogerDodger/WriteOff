use 5.01;
use autodie;
use File::Temp qw/tempfile/;
use FindBin '$Bin';
BEGIN {
	chdir "$Bin/../../..";
	push @INC, './lib';
}
use WriteOff::Schema;

my $s = WriteOff::Schema->connect("dbi:SQLite:data/WriteOff.db","","", {
	sqlite_unicode => 1,
});

for my $record ($s->resultset('Event')->find(36)->vote_records) {
	$record->recalibrate;
}
