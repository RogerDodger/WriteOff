package WriteOff::View::Email::Template;

use utf8;
use strict;
use base 'Catalyst::View::Email::Template';

__PACKAGE__->config(
	stash_key => 'email',
	default => {
		content_type => 'text/html',
		charset => 'utf-8',
		view => 'HTML',
	},
);

=head1 NAME

WriteOff::View::Email::Template - Templated Email View for WriteOff

=head1 DESCRIPTION

View for sending template-generated email from WriteOff.

=head1 AUTHOR

Cameron Thornton E<lt>cthor@cpan.orgE<gt>

=head1 SEE ALSO

L<WriteOff>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
