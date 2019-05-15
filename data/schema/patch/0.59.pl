use 5.01;
use autodie;
use FindBin '$Bin';
BEGIN {
   chdir "$Bin/../../..";
   push @INC, './lib';
}
use WriteOff::Schema;

`sqlite3 data/WriteOff.db < data/schema/patch/0.59.sql`;

my $s = WriteOff::Schema->connect("dbi:SQLite:data/WriteOff.db","","", {
   sqlite_unicode => 1,
});

for my $event ($s->resultset('Event')->all) {
   for my $round ($event->rounds->search({ action => 'vote' })) {
      my $rel = 0;
      my $abs = 0;
      for my $ballot ($round->ballots) {
         my $votes = $ballot->votes->search({ value => { '!=' => undef } });
         next unless $votes->count;

         my $avg = $votes->get_column('value')->func('avg');
         if ($avg == 0 || $avg == $votes->count / 2 || $avg + 1 == $votes->count / 2 || $avg == ($votes->count - 1) / 2) {
            $rel++;
         }
         else {
            $abs++;
         }
      }

      $round->ballots->update({ absolute => $abs > $rel });
   }
}
