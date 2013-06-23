#!/usr/bin/env perl

use FindBin '$Bin';
use lib "$Bin/../lib";
use WriteOff::Command;

chdir("$Bin/..");
WriteOff::Command->run(@ARGV);
