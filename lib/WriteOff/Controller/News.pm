package WriteOff::Controller::News;
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller'; }

=head1 NAME

WriteOff::Controller::News - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut


=head2 list

=cut

sub list :Path :Args(0) {
    my ( $self, $c ) = @_;
	require DateTime::Format::SQLite;
	
	$c->stash->{times} = [
		DateTime::Format::SQLite->parse_datetime('2012-11-17 17:45:00'),
		DateTime::Format::SQLite->parse_datetime('2012-11-14 16:50:00'),
	];
	
	$c->stash->{title} = 'News';
    $c->stash->{template} = 'news/list.tt';
}


=head1 AUTHOR

Cameron Thornton E<lt>cthor@cpan.orgE<gt>

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
