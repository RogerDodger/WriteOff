#!/usr/bin/env perl
use v5.14;
use warnings;

use FindBin '$Bin';
BEGIN {
   chdir "$Bin/../..";
   push @INC, './lib';
}
use WriteOff::Schema;
use WriteOff::Award qw/:all/;

my $s = WriteOff::Schema->connect("dbi:SQLite:data/WriteOff.db","","");
$s->storage->dbh->sqlite_enable_load_extension(1);
$s->storage->dbh->sqlite_load_extension('./bin/libsqlitebcsum.so');

my $aa = $s->resultset('ArtistAward');
my $artists = $s->resultset('Artist');
my @medals = ( GOLD, SILVER, BRONZE );

my @data;

for my $e ($s->resultset('Event')->all) {
   say "Event " . $e->id . "...";
   for my $itype (qw/story image/) {
      my $type = { story => 'fic', image => 'art' }->{$itype};
      my $tname = "${itype}s";
      my $colname = "${itype}_id";

      my %meta = (event_id => $e->id, type => $type);
      my %artists;

      my $items = $e->$tname;
      my $cnfti = $items->get_column('public_stdev')->max;
      my $spoon = $items->count - 1;
      for my $item ($items->order_by({ -asc => 'rank' })->all) {
         my @awards = (
            $medals[$item->rank] // (),
            $cnfti && $item->public_stdev == $cnfti ? (CONFETTI) : (),
            $item->rank == $spoon ? (SPOON) : (),
         );

         my $artist = $artists->search({ name => $item->artist });
         if ($artist->count != 1) {
            warn "Weirdness with artist " . $item->artist;
            next;
         }
         my $aid = $artist->first->id;

         if (!exists $artists{$aid}) {
            $artists{$aid} = [ [ $item, RIBBON ] ];
         }

         for my $award (@awards) {
            push @{ $artists{$aid} }, [ $item, $award ];
         }
      }

      while (my ($aid, $awards) = each %artists) {
         # Shift ribbon off
         if (@$awards != 1) {
            shift @$awards;
         }

         for (@$awards) {
            my ($item, $award) = @$_;

            push @data, { %meta,
               artist_id => $aid,
               $colname  => $item->id,
               award_id  => $award->id,
            };
         }
      }
   }
}

say "Populating...";
$aa->delete;
$aa->populate([ grep { !exists $_->{image_id} } @data ]);

# For some extraordinarily bizarre and unexplainable reason, ->populate
# removes the image_id column from all the art rows, so we do it the slow way
$aa->create($_) for grep { exists $_->{image_id} } @data;


$artists->recalculate_scores;
