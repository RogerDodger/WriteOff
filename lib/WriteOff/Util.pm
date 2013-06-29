package WriteOff::Util;
use utf8;

use strict;
use warnings;
use base 'Exporter';
our @EXPORT_OK = qw/wordcount simple_uri sorted/;
our %EXPORT_TAGS = ( all => \@EXPORT_OK );

sub wordcount ($) {
	my $str = shift or return 0;
	
	return scalar split /\s+/, $str;
}

sub simple_uri {
	local $_ = join "-", @_;
	
	s/[\\\/—–]/ /g; #Turn punctuation that commonly divide words into spaces
	s/[^a-zA-Z0-9\-\x20]//g; # Remove all except English letters,
	                         # Arabic numerals, hyphens, and spaces.
	s/^\s+|\s+$//g; #Trim
	s/[\s\-]+/-/g; #Collate spaces and hyphens into a single hyphen
	
	return $_;
}

sub sorted {
	my $cmp = ref $_[0] eq 'CODE' ? shift : sub { $_[0] cmp $_[1] };

	my $prev = shift;
	for my $curr (@_) {
		return 0 if $cmp->($prev, $curr) > 0;
		$prev = $curr;
	}
	1;
}

1;

__END__

=pod

=head1 NAME

WriteOff::Util - miscellenous subs used in L<WriteOff>

=head1 METHODS

=head2 wordcount

Returns the wordcount of a given string.

=head2 simple_uri

Performs one-way substitutions on arguments to return a URI-safe string for
human-readable (but lossy) URIs.

=head2 sorted

    sorted 1, 2, 3;                          # True
    sorted 1, 3, 9;                          # True
    sorted 1, 2, 10;                         # False
    sorted sub { $_[0] <=> $_[1] } 1, 2, 10; # True

Returns true if the arguments are sorted and false otherwise. Takes an
optional code ref which will do the comparisons. Defaults to string
comparison.

=head1 AUTHOR

Cameron Thornton E<lt>cthor@cpan.orgE<gt>

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
