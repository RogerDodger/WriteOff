package WriteOff::Schema::ResultSet::Genre;

use strict;
use base 'WriteOff::Schema::ResultSet';

sub promoted {
   shift->search({ promoted => 1 });
}

sub with_counts {
   my $self = shift;

   my $entry_count = $self->search({
      'inn.id' => { -ident => 'me.id' },
   }, {
      join => { events => 'entrys' },
      select => { count => 'entrys.id' },
      group_by => 'inn.id',
      alias => 'inn',
   });

   my $member_count = $self->search({
      'inn.id' => { -ident => 'me.id' },
   }, {
      join => { 'members' },
      # Include the owner in the member count
      select => \'count(members.artist_id) + 1',
      group_by => 'inn.id',
      alias => 'inn',
   });

   $self->search({}, {
      join => 'events',
      '+select' => [
         { count => 'events.id', -as => 'event_count' },
         { '' => $entry_count->as_query, -as => 'entry_count' },
         { '' => $member_count->as_query, -as => 'member_count' },
      ],
      '+as' => [qw/
         event_count
         entry_count
         member_count
      /],
      group_by => 'me.id',
      order_by => { -desc => 'entry_count' },
   });
}

1;
