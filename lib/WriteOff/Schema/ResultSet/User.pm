package WriteOff::Schema::ResultSet::User;

use strict;
use base 'WriteOff::Schema::ResultSet';

sub resolve {
	my ($self, $user) = @_;
	return 0 unless $user;
	
	return $user->get_object if eval
		{ $user->isa('Catalyst::Authentication::Store::DBIx::Class::User') };
		
	return $user if eval { $user->isa('WriteOff::Model::DB::User') };
	return $self->find($user) or 0;
}

1;