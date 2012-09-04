#!/usr/bin/perl

use strict;
use warnings;
BEGIN { push @INC, 'lib'; }

use WriteOff::Schema;
use DateTime;
my $schema = WriteOff::Schema->connect('dbi:SQLite:WriteOff.db');

$schema->resultset('Schedule')->create({
   at => DateTime->now,
   action => '/event/set_prompt',
   args => [1],
});
