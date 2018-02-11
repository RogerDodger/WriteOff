use 5.01;
use autodie;
use FindBin '$Bin';
BEGIN {
	chdir "$Bin/../../..";
	push @INC, './lib';
}
use WriteOff::Schema;

my $s = WriteOff::Schema->connect("dbi:SQLite:data/WriteOff.db","","", {
	sqlite_unicode => 1,
});

$_->update({ name_canonical => CORE::fc $_->name }) for $s->resultset('Artist')->all;
