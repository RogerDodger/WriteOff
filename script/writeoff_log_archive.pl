#!/usr/bin/env perl

use 5.014;
use DateTime;
use IO::Compress::Gzip qw/gzip $GzipError/;

my $logfile = 'writeoff.log';
die "$logfile does not exist" unless -e $logfile;

my $dt = DateTime->now->ymd;
my $out = "$logfile.$dt.gz";
for( my $i = 0; -e $out; $i++ ) { 
	$out = "$logfile.$dt.$i.gz";
}

say "Compressing logs to $out";
gzip $logfile => $out
	or die "gzip failed: $GzipError\n";

unlink $logfile;