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

=head2 clean_old_heats

Cleans old data from the database.

=cut

sub check_schedule :Private {
	my ( $self, $c ) = @_;
	
	my $rs = $c->model('DB::Schedule')->active_schedules;
	
	while (my $row = $rs->next) {
		$c->forward($row->action, [$row->args]);
		$row->delete;
	}
}

sub cleanup :Private {
	my ( $self, $c ) = @_;
	
	$c->model('DB::Heat')->clean_old_entries;
}


=head1 AUTHOR

Cameron Thornton

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
