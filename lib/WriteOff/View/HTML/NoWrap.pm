package WriteOff::View::HTML::NoWrap;
use Moose;
use namespace::autoclean;

extends 'Catalyst::View::TT';

__PACKAGE__->config(
    TEMPLATE_EXTENSION => '.tt',
    render_die => 1,
);

=head1 NAME

WriteOff::View::HTML::NoWrap - TT View for WriteOff

=head1 DESCRIPTION

TT View for WriteOff.

=head1 SEE ALSO

L<WriteOff>

=head1 AUTHOR

Cameron,,,

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
