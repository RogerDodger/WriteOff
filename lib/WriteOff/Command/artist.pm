package WriteOff::Command::artist;

use WriteOff::Command;
use Encode;

can color =>
   sub {
      for my $artist (db('Artist')->all) {
         $artist->avatar_write_color->update;

         printf "%16s %7s %s\n",
            $artist->avatar_id // 'default.jpg',
            $artist->color // '',
            Encode::encode_utf8 $artist->name;
      }
   },
   which => q{
      Assigns a color to artist from avatar for all artists.
   },
   fetch => 0;

1;
