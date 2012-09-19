#!/usr/bin/perl

BEGIN { push @INC, 'lib' }
use 5.014;

use DBI;
use DateTime;

my $dbname = 'WriteOff.db';
my $dbh = DBI->connect("dbi:SQLite:dbname=$dbname","","");

my $dt = DateTime->now->ymd;
my $fn = "$dbname.$dt";
for( my $i = 0; -e $fn; $i++ ) { 
	$fn = "$dbname.$dt.$i";
}

say "Backing up to $fn";
$dbh->sqlite_backup_to_file($fn);

if ( $fn = shift ) {
	die "$fn doesn't exist" unless -e $fn;
	say "Backing up from $fn";
	$dbh->sqlite_backup_from_file($fn);
}