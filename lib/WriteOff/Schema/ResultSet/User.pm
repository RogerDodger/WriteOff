package WriteOff::Schema::ResultSet::User;

use strict;
use base 'WriteOff::Schema::ResultSet';

sub user_exists {
	my ($self, $user) = @_;
	
	return $self->search({username => {like => $user} })->count && 1;
}

sub email_exists {
	my ($self, $email) = @_;
	
	return $self->search({email => {like => $email} })->count && 1;
}

1;