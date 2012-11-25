package WriteOff::Helpers;

use base 'Exporter';
use utf8;
our @EXPORT_OK = qw/wordcount simple_uri/;

sub wordcount {
	my $str = shift or return 0;
	
	return scalar split /\s+/, $str;
}

sub simple_uri {
	my $str = join "-", @_;
	
	for ( $str ) {
		s/[\\\/—–]/ /g; #Turn punctuation that commonly divide words into spaces

		s/[^a-zA-Z0-9\-\x20]//g; # Remove all except English letters, 
		                         # arabic numerals, hyphens, and spaces.
		s/^\s+|\s+$//g; #Trim
		s/[\s\-]+/-/g; #Collate spaces and hyphens into a single hyphen
	}
	
	return $str;
}

1;

__END__

=pod

=head1 NAME

WriteOff::Helpers - miscellenous subs used in L<WriteOff>

=head1 METHODS

=head2 wordcount

Returns the wordcount of a given string.

=head2 simple_uri

Performs one-way substitutions on arguments to return a URI-safe string for
human-readable (but lossy) URIs.

=head1 AUTHOR

Cameron Thornton E<lt>cthor@cpan.orgE<gt>

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut