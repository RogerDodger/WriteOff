package WriteOff::Command::log;

use POSIX 'strftime';
use IO::Compress::Gzip qw/gzip $GzipError/;
use Time::gmtime;
use WriteOff::Command;

my $ts = strftime('%Y-%m-%d', @{ gmtime() });

can compress =>
   sub {
      for my $in (glob "log/*.log") {
         my $out = $in =~ s{^ (.+?) \. (.+) $}{$1-$ts.$2.gzip}rx;

         -e $out or abort qq{! $out already exists};
         gzip $in => $out or abort qq{gzip failed: $GzipError};

         say STDERR "+ $in => $out";
         unlink $in;
      }
   },
   which => q{
      Compresses logs with gzip.
   },
   fetch => 0;

1;
