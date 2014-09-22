#!/usr/bin/env perl
use v5.14;
use warnings;

use FindBin '$Bin';
BEGIN {
	chdir "$Bin/../..";
	push @INC, './lib';
}
use WriteOff::Schema;
use WriteOff::Award qw/:all/;

my $s = WriteOff::Schema->connect("dbi:SQLite:data/WriteOff.db","","");
$s->storage->dbh->sqlite_enable_load_extension(1);
$s->storage->dbh->sqlite_load_extension('./bin/libsqlitefunctions.so');

my $artists = $s->resultset('Artist');
my $scores = $s->resultset('Score');

$scores->delete;

for my $e ($s->resultset('Event')->finished->all) {
	printf "%02d %10s\n", $e->id, $e->prompt;
	$scores->decay;

	$artists->_score($e->storys_rs);
	$artists->_score($e->images_rs) if $e->art;
}

$artists->recalculate_scores;
