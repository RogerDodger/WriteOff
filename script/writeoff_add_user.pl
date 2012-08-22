#!/usr/bin/perl

use strict;
use warnings;
BEGIN { push @INC, 'lib'; }

use WriteOff::Schema;
use Getopt::Long;
my $help = 0;
GetOptions('help' => \$help);
if($help) {
	print "\tusage: user_add.pl username password role\n";
	exit;
}

my $schema = WriteOff::Schema->connect('dbi:SQLite:WriteOff.db');

my($user, $pass, $role) = @ARGV;

my %id = (
	admin => 1,
	user  => 2,
);

die "Not a defined role" unless defined $id{$role};

my $entry = $schema->resultset('User')->create({
	username => $user,
	password => $pass,
	verified => 1,
});

$schema->resultset('UserRole')->create({
	user_id => $entry->id,
	role_id => $id{$role},
});
