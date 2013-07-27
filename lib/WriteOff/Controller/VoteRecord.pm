package WriteOff::Controller::VoteRecord;
use Moose;
use namespace::autoclean;
no warnings "uninitialized";

BEGIN { extends 'Catalyst::Controller'; }

__PACKAGE__->config(fetch => 'record');

sub _fetch :ActionClass('~Fetch') {}

sub fetch :Chained('/') :PathPart('voterecord') :CaptureArgs(1) {
	my ($self, $c) = @_;
	$c->forward('_fetch');
	$c->stash->{event} = $c->stash->{record}->event;
	push $c->stash->{title}, 'Vote Record #' . $c->stash->{record}->id;
}

sub view :Chained('fetch') :PathPart('') :Args(0) {
	my ( $self, $c ) = @_;

	$c->detach('/default') unless $c->stash->{record}->is_filled;
	if (!$c->stash->{record}->is_publicly_viewable) {
		$c->forward('/event/assert_organiser');
	}

	my $organiser_referer = $c->uri_for(
		$c->controller('Event')->action_for('view'),
		[ $c->stash->{event}->id_uri ]
	);
	my $results_referer = $c->uri_for(
		$c->controller('Event')->action_for('results'),
		[ $c->stash->{event}->id_uri ]
	);

	if (!$c->stash->{event}->is_organised_by($c->user)) {
		$c->session->{vote_record_view_state} = 'public';
	}
	elsif ($c->req->referer eq $organiser_referer) {
		$c->session->{vote_record_view_state} = 'all';
	}
	elsif ($c->req->referer eq $results_referer) {
		$c->session->{vote_record_view_state} = 'judges';
	}

	my $records = $c->stash->{event}->vote_records->filled->ordered;
	unless ($c->session->{vote_record_view_state} eq 'all') {
		$records = $records->judge_records;
	}

	my @records = $records->all;

	for (my $i = 0; $i <= $#records; $i++) {
		if ($c->stash->{record}->id == $records[$i]->id) {
			$c->stash->{prev} = $records[$i-1];
			$c->stash->{i} = ++$i;
			$c->stash->{next} = $records[$i % @records];
			last;
		}
	}

	$c->stash->{template} = 'voterecord/view.tt';
}

sub delete :Chained('fetch') :PathPart('delete') :Args(0) {
	my ( $self, $c ) = @_;

	$c->detach('/default') unless $c->stash->{record}->is_filled;
	$c->forward( $c->controller('Event')->action_for('assert_organiser') );

	$c->stash->{key} = {
		name  => 'count',
		value => $c->stash->{record}->votes->count,
	};

	$c->forward('do_delete') if $c->req->method eq 'POST';

	push $c->stash->{title}, 'Delete';
	$c->stash->{template} = 'item/delete.tt';
}

sub do_delete :Private {
	my ( $self, $c ) = @_;

	$c->forward('/check_csrf_token');

	$c->log->info( sprintf "VoteRecord deleted by %s: %s (%s)",
		$c->user->get('username'),
		$c->stash->{record}->ip,
		eval { $c->stash->{record}->user->username } || 'Guest',
	);

	$c->stash->{record}->votes->delete_all;

	$c->flash->{status_msg} = 'Deletion successful';
	$c->res->redirect( $c->uri_for(
		$c->controller('Event')->action_for('view'),
		[ $c->stash->{event}->id_uri ],
	) );
}

sub fill :Chained('fetch') :PathPart('fill') :Args(0) {
	my ( $self, $c ) = @_;

	$c->detach('/forbidden', [ "You do not own this record." ])
		unless $c->stash->{record}->user_id == $c->user_id;
	$c->detach('/error', [ "This record is already filled." ])
		unless $c->stash->{record}->is_unfilled;
	$c->detach('/error', [ "It is too late to fill this record." ])
		unless $c->stash->{record}->is_fillable;

	push $c->stash->{title}, 'Fill';
	$c->stash->{template} = 'voterecord/fill.tt';

	$c->forward('do_fill') if $c->req->method eq 'POST';
}

sub do_fill :Private {
	my ( $self, $c ) = @_;

	$c->forward('/check_csrf_token');

	my @params = split ";", $c->req->param('data');
	my $vote_ids = $c->stash->{record}->votes->get_column('id');

	$c->detach('/error', [ 'Bad form input' ])
		unless [ $vote_ids->all ] ~~ [ sort { $a <=> $b } @params ];

	for( my $p = 0; $p <= $#params; $p++ ) {
		$c->model('DB::Vote')->find( $params[$p] )->update({
			value => $#params - 2 * $p,
		});
	}

	$c->stash->{record}->update({ ip => $c->req->address });

	$c->flash->{status_msg} = 'Vote successful';
	$c->res->redirect( $c->uri_for(
		$c->controller('Vote')->action_for( $c->stash->{record}->round ),
		[ $c->stash->{event}->id_uri ]
	) );
}

=head1 AUTHOR

Cameron Thornton E<lt>cthor@cpan.orgE<gt>

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
