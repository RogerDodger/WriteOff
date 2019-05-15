use 5.01;
use autodie;
use File::Temp qw/tempfile/;
use FindBin '$Bin';
BEGIN {
   chdir "$Bin/../..";
   push @INC, './lib';
}
use WriteOff::Schema;

my $s = WriteOff::Schema->connect("dbi:SQLite:data/WriteOff.db","","", {
   sqlite_unicode => 1,
});

for my $img ($s->resultset('Image')->all) {
   my ($fh, $tmp) = tempfile();
   print $fh $img->contents;
   close $fh;
   my $e = $img->write($tmp);
   warn "$e\n" if $e;
}
