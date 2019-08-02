#!/usr/bin/env perl

use v5.14;
use strict;
use warnings;
use Test::More;
use Test::Deep;

BEGIN {
   use_ok 'WriteOff::Award';
   WriteOff::Award->import(':all');
}

my $award = GOLD;

isa_ok $award, 'WriteOff::Award';

is $award->id, 1, 'Award attributes';
is $award->name, 'gold', 'Award attributes';
is $award->type, 'gold', 'Award attributes';
is $award->alt, 'Gold medal', 'Award attributes';
is $award->src, '/static/images/awards/gold.svg', 'Award attributes';
is $award->html, q{<img class="Award gold" src="/static/images/awards/gold.svg" }
               . q{alt="Gold medal" title="First place">}, 'Award attributes';

cmp_deeply(
   [
      sort_awards GOLD, BRONZE, GOLD, RIBBON, SILVER,
      CONFETTI, RIBBON, CONFETTI, SPOON, SPOON, GOLD, CONFETTI,
   ],
   [
      GOLD, GOLD, GOLD, SILVER, BRONZE, CONFETTI,
      CONFETTI, CONFETTI, SPOON, SPOON, RIBBON, RIBBON,
   ],
   'Awards sort correctly',
);

done_testing;
