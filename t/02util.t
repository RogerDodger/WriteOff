#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;

BEGIN { use_ok "WriteOff::Util", ':all';  }

is
   wordcount("The quick black fox jumps over the lazy dog"),
   9,
   'wordcount',
;

is
   wordcount "The quick black fox jumps over the lazy dog",
   9,
   'wordcount has ($) prototype',
;

is
   simple_uri(19, 'Foo Bar Baz'),
   '19-Foo-Bar-Baz',
   'simple_uri',
;

ok
   sorted(1, 2, 3, 4),
   'sorted defaults to ascending cmp'
;
ok
   !sorted(0, 1, 2, 10),
   'sorted defaults to string cmp',
;
ok
   sorted(0, 1, 10, 2),
   'sorted defaults to string cmp',
;
ok
   sorted(sub { $_[0] <=> $_[1] }, 0, 1, 2, 10),
   'sorted w/custom comparator',
;
ok
   sorted(sub { $_[0] <=> $_[1] }, sort { $a <=> $b } 1, 4, "10", 2),
   'sorted w/custom comparator',
;

done_testing;
