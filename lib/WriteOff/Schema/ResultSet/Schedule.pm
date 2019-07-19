package WriteOff::Schema::ResultSet::Schedule;

use strict;
use base 'WriteOff::Schema::ResultSet';

sub active {
   my $self = shift;

   $self->search({
      next => { '<=' =>
         $self->format_datetime($self->now_dt->clone->add(days => 2))
      }
   });
}

sub index {
   shift->search({}, {
      order_by => 'next',
      prefetch => [qw/format genre/],
   })
}

sub promoted {
   shift->search({ promoted => 1 }, { join => 'genre' });
}

1;
