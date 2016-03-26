package WriteOff::Controller::Cron;
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller'; }

=head1 NAME

WriteOff::Controller::Cron - Catalyst Controller

=head1 DESCRIPTION

Application cron actions.

=head1 METHODS

=head2 check_schedule

Checks the schedule table and executes any actions that are set to be executed,
deleting them afterwards (such that a scheduled task only executes once).

=head2 cleanup

Cleans old data from the database.

=cut

sub auto :Private {
	my ($self, $c) = @_;

	substr($c->req->address, -9) eq '127.0.0.1' or $c->detach('/default');
}

sub cleanup :Local {
	my ( $self, $c ) = @_;

	$c->model('DB::User')->clean_unverified;
	$c->model('DB::Token')->clean_expired;
}

sub clear :Local {
	my ($self, $c) = @_;

	$c->config->{renderCache}->clear;
	$c->config->{pageCache}->clear;
	$c->config->{scoreCache}->clear;
}

sub schedule :Local {
	my ( $self, $c ) = @_;

	my $rs = $c->model('DB::Schedule')->active_schedules;

	# Extract and delete schedules *before* executing them, lest long-running
	# tasks execute twice.
	my @schedules = $rs->all;
	$rs->delete;

	$c->forward($_->action, $_->args) for @schedules;
}

sub end :Private {
	my ($self, $c) = @_;

	$c->res->body('Task complete');
}

=head1 AUTHOR

Cameron Thornton E<lt>cthor@cpan.orgE<gt>

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
