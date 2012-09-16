package WriteOff::Checker;
use strict;
use FormValidator::Simple::Exception;
use FormValidator::Simple::Constants;

sub SCALAR {
	my ( $self, $params, $args ) = @_;
	
	return $params->[0] =~ m{^ARRAY\(.+\)$} ? FALSE : TRUE;
} 

1;