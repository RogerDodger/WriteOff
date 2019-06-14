package WriteOff::Schema::ResultSet::Genre;

use strict;
use base 'WriteOff::Schema::ResultSet';

sub with_counts {
   my $self = shift;

   my $subq = $self->search({
      'inn.id' => { -ident => 'me.id' },
   }, {
      join => { events => 'entrys' },
      select => { count => 'entrys.id' },
      group_by => 'inn.id',
      alias => 'inn',
   });

   $self->search({}, {
      join => [
         'members',
         'events',
      ],
      '+select' => [
         { count => 'members.artist_id' },
         { count => 'events.id' },
         { '' => $subq->as_query, -as => 'entry_count' },
      ],
      '+as' => [qw/
         member_count
         event_count
         entry_count
      /],
      group_by => 'me.id',
      order_by => { -desc => 'entry_count' },
   });
}

1;
