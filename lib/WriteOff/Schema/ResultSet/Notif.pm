package WriteOff::Schema::ResultSet::Notif;

use strict;
use base 'WriteOff::Schema::ResultSet';

sub unread {
   shift->search({ read => 0 });
}

sub unread_rs {
   scalar shift->unread;
}

1;
