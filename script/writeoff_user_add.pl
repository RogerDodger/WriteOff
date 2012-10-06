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

$role = $schema->resultset('Role')->find({ role => $role }) 
	|| die "Role '$role' does not exist";

$schema->resultset('User')->create({
	username => $user,
	password => $pass,
	verified => 1,
})->add_to_roles($role);

1;