package WriteOff::Controller::Scoreboard;
use Moose;
use WriteOff::Award qw/:all/;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller'; }

sub index :Path('') :Args(0) {
	my ( $self, $c ) = @_;

	$c->stash->{artists} = [ $c->model('DB::Artist')->tallied ];
	$c->stash->{gold_medal} = GOLD();

	push $c->stash->{title}, 'Scoreboard';
	$c->stash->{template} = 'scoreboard/index.tt';
}

sub alltime :Local {
	my ($self, $c) = @_;

	$c->stash->{artists} = [ $c->model('DB::Artist')->tallied(1) ];
	$c->stash->{gold_medal} = GOLD();

	push $c->stash->{title}, 'Scoreboard';
	$c->stash->{template} = 'scoreboard/index.tt';
}

=head1 AUTHOR

Cameron Thornton E<lt>cthor@cpan.orgE<gt>

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
