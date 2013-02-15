#!/usr/bin/perl

use strict;
use warnings;
use 5.014;
BEGIN { push @INC, 'lib'; }

use WriteOff::Schema;
my $schema = WriteOff::Schema->connect('dbi:SQLite:WriteOff.db');

