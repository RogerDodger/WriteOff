package WriteOff::Schema::ResultSet::User;

use strict;
use base 'DBIx::Class::ResultSet';

sub user_exists {
	my ($self, $user) = @_;
	
	return 0 unless $self->search({username => {like => $user} })->all;
	1;
}

sub email_exists {
	my ($self, $email) = @_;
	
	return 0 unless $self->search({email => {like => $email} })->all;
	1;
}

sub new_token_for {
	my ($self, $email) = @_;
	
	my $row = $self->find({email => $email});
	my $token = Digest->new('MD5')
		->add( join("", time, $row->password, rand(10000), $$) )
		->hexdigest;
		
	$row->update({ token => $token });
	
	return $token;
}

1;