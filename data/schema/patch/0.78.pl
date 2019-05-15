use 5.01;
use autodie;
use FindBin '$Bin';
BEGIN {
   chdir "$Bin/../../..";
   push @INC, './lib';
}
use WriteOff::Award qw/:all/;
use WriteOff::Mode;
use WriteOff::Schema;

my $s = WriteOff::Schema->connect("dbi:SQLite:data/WriteOff.db","","", {
   sqlite_unicode => 1,
});

$s->resultset('Entry')->update({
   score_format => \'score',
   score_genre => \'score',
});

my $rounds = $s->resultset('Round')->search({
   action => 'vote',
   name => 'final',
   "me.tallied" => 1,
}, { prefetch => 'event' });

my $scores = $s->resultset('Entry')->search(
   { score => { '!=' => undef } },
   { join => 'event' },
);

for my $round ($rounds->ordered->all) {
   my $event = $round->event;
   print $event->id / 10, "\n" if $round->mode eq 'fic' && $event->id % 10 == 0;

   my $pScores = $scores->search({
      'event.created' => { '<' => $scores->format_datetime($event->created) },
      WriteOff::Mode->find($round->mode)->fkey => { '!=' => undef },
   });

   my $gScores = $pScores->search({ genre_id => $event->genre_id });
   $gScores->update({ score_genre => \q{score_genre * 0.9} });

   my $fScores = $gScores->search({ format_id => $event->format_id });
   $fScores->update({ score_format => \q{score_format * 0.9} });

   # We missed some slueth awards before from buggy code
   if ($event->id >= 69) {
      my $theorys = $event->theorys->mode($round->mode);
      $theorys->update({ award_id => undef });
      $theorys->process;
   }
}
