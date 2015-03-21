package WriteOff::Controller::Prompt;
use Moose;
use WriteOff::Util qw/uniq/;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller'; }

=head1 NAME

WriteOff::Controller::Prompt - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=head2 index

=cut

sub fetch :Chained('/') :PathPart('prompt') :CaptureArgs(1) :ActionClass('~Fetch') {}

sub vote :Chained('/event/prompt') :PathPart('vote') :Args(0) {
	my ( $self, $c ) = @_;

	$c->stash->{prompts} = $c->stash->{event}->prompts;

	if ($c->stash->{event}->prompt_type eq 'approval') {
		$c->stash->{show_results} = $c->stash->{event}->has_started
		                         || $c->stash->{event}->is_organised_by($c->user);

		$c->stash->{user_has_voted} = $c->model("DB::UserEvent")->find(
			$c->user_id,
			$c->stash->{event}->id,
			'prompt-voter',
		);

		$c->stash->{votes_received} = $c->model("DB::UserEvent")->search({
			event_id => $c->stash->{event}->id,
			role => 'prompt-voter'
		})->count;
	}

	if ($c->stash->{event}->prompt_votes_allowed) {
		if ($c->stash->{event}->prompt_type eq 'faceoff') {
			$c->forward('do_vote_faceoff') if $c->req->method eq 'POST';

			$c->stash->{heat} = $c->model('DB::Heat')->get_or_new_heat(
				$c->stash->{event},
				$c->req->address,
			);
		}
		elsif ($c->stash->{event}->prompt_type eq 'approval') {
			$c->forward('do_vote_approval') if $c->req->method eq 'POST';
		}
	}

	$c->stash->{template} = 'prompt/vote.tt';
}

sub do_vote_faceoff :Private {
	my ( $self, $c ) = @_;

	my $heat = $c->model('DB::Heat')->find( $c->req->params->{heat} ) or
		return 0;

	my $result;
	$result //= 1   if $c->req->params->{left};
	$result //= 0.5 if $c->req->params->{tie};
	$result //= 0   if $c->req->params->{right};

	$heat->do_heat( $c->stash->{event}, $c->req->address, $result );
}

sub do_vote_approval :Private {
	my ( $self, $c ) = @_;

	return if !$c->user || $c->stash->{user_has_voted};

	my $prompts = $c->stash->{event}->prompts;

	for my $vote (uniq $c->req->param('vote')) {
		if (my $prompt = $prompts->find($vote)) {
			$prompt->update({ approvals => $prompt->approvals + 1 });
		}
	}

	$c->model("DB::UserEvent")->create({
		user_id  => $c->user_id,
		event_id => $c->stash->{event}->id,
		role     => 'prompt-voter',
	});
	$c->stash->{status_msg} = 'Thank you for voting!';
	$c->stash->{user_just_voted} = 1;
}

sub submit :Chained('/event/prompt') :PathPart('submit') :Args(0) {
	my ( $self, $c ) = @_;

	my $subs_left = sub {
		return 0 unless $c->user;
		return $c->config->{prompts_per_user} -
		$c->stash->{event}->prompts->search({ user_id => $c->user_id })->count;
	};

	$c->req->params->{subs_left} = $subs_left->();

	$c->forward('do_submit')
		if $c->req->method eq 'POST'
		&& $c->user
		&& $c->stash->{event}->prompt_subs_allowed;

	$c->stash->{subs_left} = $subs_left->();

	push $c->stash->{title}, 'Submit';
	$c->stash->{template} = 'prompt/submit.tt';
}

sub do_submit :Private {
	my ( $self, $c ) = @_;

	$c->forward('/check_csrf_token');

	$c->form(
		prompt => [
			'NOT_BLANK',
			[ 'LENGTH', 1, $c->config->{len}{max}{prompt} ],
			'TRIM_COLLAPSE',
			[ 'DBIC_UNIQUE', $c->stash->{event}->prompts_rs, 'contents' ],
		],
		subs_left => [ [ 'GREATER_THAN', 0 ] ],
	);

	if (!$c->form->has_error) {
		my %row = (
			user_id  => $c->user->id,
			ip       => $c->req->address,
			contents => $c->form->valid('prompt'),
		);

		if ($c->stash->{event}->prompt_type eq 'faceoff') {
			$row{rating} = $c->config->{elo_base};
		} elsif ($c->stash->{event}->prompt_type eq 'approval') {
			$row{approvals} = 0;
		} else {
			$c->log->warn(sprintf "Event %d has unknown prompt type %s",
				$c->stash->{event}->id,
				$c->stash->{event}->prompt_type,
			);
			return $c->stash->{error_msg} = 'Something went wrong...';
		}

		$c->stash->{event}->create_related('prompts', \%row);
		$c->stash->{status_msg} = 'Submission successful';
	}
}

sub delete :Chained('fetch') :PathPart('delete') :Args(0) {
	my ( $self, $c ) = @_;

	$c->detach('/forbidden', ['You cannot delete this item.']) unless
		$c->stash->{prompt}->is_manipulable_by( $c->user );

	$c->stash->{key} = {
		name  => 'prompt',
		value => $c->stash->{prompt}->contents,
	};

	$c->forward('do_delete') if $c->req->method eq 'POST';

	push $c->stash->{title}, 'Delete';
	$c->stash->{template} = 'item/delete.tt';
}

sub do_delete :Private {
	my ( $self, $c ) = @_;

	$c->forward('/check_csrf_token');

	$c->log->info( sprintf "Prompt deleted by %s: %s (%s - %s)",
		$c->user->name,
		$c->stash->{prompt}->contents,
		$c->stash->{prompt}->ip,
		$c->stash->{prompt}->user->username,
	);

	$c->stash->{prompt}->delete;

	$c->flash->{status_msg} = 'Deletion successful';
	$c->res->redirect( $c->req->param('referer') || $c->uri_for('/') );
}

=head1 AUTHOR

Cameron Thornton

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
