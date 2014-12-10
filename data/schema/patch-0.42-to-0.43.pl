use 5.01;
use autodie;
use File::Spec;
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
	my $thumb = 0;
	for ($img->contents, $img->thumb) {
		open my $fh, '>', File::Spec->catfile('root', $img->path($thumb++));
		print $fh $_;
		close $fh;
	}
}
