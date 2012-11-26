#!/usr/bin/env perl

#Renames an artist on the scoreboard and in any Story or Image records
use 5.014;
use FindBin '$Bin';
use lib "$Bin/../lib";
use WriteOff::Schema;

my $schema = WriteOff::Schema->connect('dbi:SQLite:WriteOff.db');

my $v_artist_rs = $schema->resultset('Virtual::Artist');

my $artist = $v_artist_rs->find({ name => $ARGV[0] })
	or die "`$ARGV[0]` is not an artist in the database";

my $to = shift or die "No new name given";

say $artist->user->username;