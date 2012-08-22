package WriteOff::Schema::ResultSet::Image;

use strict;
use base 'DBIx::Class::ResultSet';

sub new_filename {
	my ($self, $ext, $fn) = @_;
	
	#for whatever reason, File::MimeInfo wants your jpeg's with a .jpe extension
	$ext =~ s/jpe/jpg/; 
	
	my @alphanum = ('a'..'z', 'A'..'Z', 0..9);
	do {
		$fn  = '';
		$fn .= $alphanum[rand(62)] for 0..4;
		$fn .= '.' . $ext;
	} while ( $self->find({ filename => $fn }) );
	
	return $fn;
}

1;