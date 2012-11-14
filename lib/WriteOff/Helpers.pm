package WriteOff::Helpers;

use base 'Exporter';
our @EXPORT_OK = 'wordcount';

sub wordcount {
	my $str = shift or return 0;
	
	return scalar split /\s+/, $str;
}

1;