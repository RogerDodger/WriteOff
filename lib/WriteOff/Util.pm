package WriteOff::Util;
use utf8;

use strict;
use warnings;
use base 'Exporter';
use Digest;
use Parse::BBCode;
use Time::HiRes qw/gettimeofday/;

our @EXPORT_OK = qw/LEEWAY maybe simple_uri sorted token wordcount uniq/;
our %EXPORT_TAGS = ( all => \@EXPORT_OK );

sub LEEWAY () { 5 } # minutes

my $bb = Parse::BBCode->new({
	tags => {
		b => '<strong>%{parse}s</strong>',
		i => '<em>%{parse}s</em>',
		u => '<span style="text-decoration: underline">%{parse}s</span>',
		s => '<del>%{parse}s</del>',
		url => '<a href="%{link}a">%{parse}s</a>',
		size => '<span style="font-size: %{size}aem;">%{parse}s</span>',
		color => '<span style="color: %{color}a;">%{parse}s</span>',
		smcaps => '<span style="font-variant: small-caps">%{parse}s</span>',
		center => {
			class => 'block',
			output => '<div style="text-align: center">%{parse}s</div>',
		},
		right => {
			class => 'block',
			output => '<div style="text-align: right">%{parse}s</div>',
		},
		quote => {
			class => 'block',
			output => '<blockquote>%{parse}s</blockquote>',
		},
		hr => {
			class => 'block',
			output => '<hr>',
			single => 1,
		},
	},
	escapes => {
		Parse::BBCode::HTML->default_escapes,
		size => sub {
			if ($_[2] =~ /^(\d+(?:\.\d+))(px|em|pt)?$/) {
				my ($em, $unit) = ($1, $2 // '');
				$em /= 16 if $unit eq 'px' || !$unit;
				$em /= 12 if $unit eq 'pt';
				return 0.5 < $em && $em < 4 ? $em : 1;
			}
			else {
				return 1;
			}
		},
		color => sub {
			$_[2] =~ /\A#?[0-9a-zA-Z]+\z/ ? $_[2] : 'inherit';
		},
	},
});

sub bbcode {
	return $bb->render($_[0]);
}

sub maybe ($$) {
	return $_[1] ? @_ : ();
}

sub simple_uri {
	local $_ = join "-", @_;

	s/[\\\/—–]/ /g; # Turn punctuation that commonly divide words into spaces
	s/[^a-zA-Z0-9\-\x20]//g; # Remove all except English letters,
	                         # Arabic numerals, hyphens, and spaces.
	s/^\s+|\s+$//g; # Trim
	s/[\s\-]+/-/g; # Collate spaces and hyphens into a single hyphen

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

sub token {
	my $salt = shift // '';
	Digest->new(shift // 'MD5')
		->add($salt)
		->add((gettimeofday)[1])
		->add(rand)->hexdigest;
}

sub wordcount ($) {
	my $str = shift or return 0;

	return scalar split /\s+/, $str;
}

sub uniq {
	my %uniq;
	$uniq{$_} = 1 for @_;
	return keys %uniq;
}

1;

__END__

=pod

=head1 NAME

WriteOff::Util - miscellenous subs used in L<WriteOff>

=head1 METHODS

=head2 simple_uri

Performs one-way substitutions on arguments to return a URI-safe string for
human-readable (but lossy) URIs.

=head2 sorted

    sorted 1, 2, 3;                           # True
    sorted 1, 3, 9;                           # True
    sorted 1, 2, 10;                          # False
    sorted sub { $_[0] <=> $_[1] }, 1, 2, 10; # True

Returns true if the arguments are sorted and false otherwise. Takes an
optional code ref which will do the comparisons. Defaults to string
comparison.

=head2 token

Returns a token for use as a nonce.

=head2 wordcount

Returns the wordcount of a given string.

=head2 uniq

Returns the unique items of a given list.

=head1 AUTHOR

Cameron Thornton <cthor@cpan.org>

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
