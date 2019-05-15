package WriteOff::Schema::ResultSet::Token;

use strict;
use warnings;
use base 'WriteOff::Schema::ResultSet';

sub clean_expired {
   my $self = shift;

   $self->search({ expires => { '<' => $self->now } })->delete;
}

sub unexpired {
   my $self = shift;
   return $self->search({ expires => { '>' => $self->now } });
}

1;
