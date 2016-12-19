package WriteOff::Controller::Cron;
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller'; }

=head1 NAME

WriteOff::Controller::Cron - Catalyst Controller

=head1 DESCRIPTION

Application cron actions.

=head1 METHODS

=head2 check_jobs

Checks the job table and executes any actions that are set to be executed,
deleting them afterwards (such that a scheduled job only executes once).

=head2 cleanup

Cleans old data from the database.

=cut

sub auto :Private {
	my ($self, $c) = @_;

	substr($c->req->address, -9) eq '127.0.0.1'
		or $c->error("Forbidden");
}

sub cleanup :Local {
	my ( $self, $c ) = @_;

	$c->model('DB::User')->clean_unverified;
	$c->model('DB::Token')->clean_expired;
}

sub clear :Local {
	my ($self, $c, $target) = @_;

	my $cache = $c->config->{$target};

	if ($cache && $cache->can('clear')) {
		$cache->clear;
	}
	else {
		$c->error("Cache $target not found");
	}
}

sub jobs :Local {
	my ( $self, $c ) = @_;

	my $rs = $c->model('DB::Job')->active;

	# Extract and delete jobs *before* executing them, lest long-running
	# jobs execute twice.
	my @jobs = $rs->all;
	$rs->delete;

	$c->forward($_->action, $_->args) for @jobs;
}

sub schedule :Local {
	my ($self, $c) = @_;

	for my $sch ($c->model('DB::Schedule')->active->all) {
		my $t0 = $sch->next;
		$sch->update({ next => $sch->next->clone->add(weeks => $sch->period) });

		$c->stash->{event} = $c->model('DB::Event')->create_from_format($t0, $sch->format, $sch->genre);
		$c->stash->{trigger} = $c->model('DB::EmailTrigger')->find({ name => 'eventCreated' });
		$c->forward('/event/notify_mailing_list');
	}
}

sub end :Private {
	my ($self, $c) = @_;

	if ($c->has_errors) {
		$c->res->body(join "\n", map "Error: $_", @{ $c->error });
		$c->error(0);
	}
	else {
		$c->res->body("Task complete\n");
	}
}

=head1 AUTHOR

Cameron Thornton E<lt>cthor@cpan.orgE<gt>

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
