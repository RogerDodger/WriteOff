package WriteOff::Schema::ResultSet::ArtistGenre;

use strict;
use base 'WriteOff::Schema::ResultSet';

sub index {
   my $self = shift;
   $self->search({}, { prefretch => 'artist' });
}

1;
