#!/usr/bin/env perl

use v5.14;
use strict;
use warnings;
use Test::More;
use Test::Deep;

BEGIN {
   use_ok 'WriteOff::Format';
   WriteOff::Format->import(':all');
}

my $format = SHORTSTORY;

isa_ok $format, 'WriteOff::Format';

is $format->id, 4, 'Format id';
is $format->limit, 9000, 'Format limit';
ok( MINIFIC()->is(MINIFIC), 'Format equals self' );
ok( WriteOff::Format->for(9000)->is(SHORTSTORY), '9000 words is Short Story' );
ok( WriteOff::Format->for(9001)->is(NOVELETTE), '9001 words is Novelette' );
ok( WriteOff::Format->for(0)->is(FLASHFIC), '0 words is Flashfic' );
ok( WriteOff::Format->for(1e12)->is(NOVEL), '1e12 words is Novel' );

done_testing;
