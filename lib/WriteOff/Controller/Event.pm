package WriteOff::Controller::Event;
use Moose;
use List::Util qw/shuffle/;
use WriteOff::Award qw/:all/;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller'; }

sub fetch :Chained('/') :PathPart('event') :CaptureArgs(1) :ActionClass('~Fetch') {}

sub permalink :Chained('fetch') :PathPart('') :Args(0) {
	my ( $self, $c ) = @_;

	$c->stash->{event}{nocollapse} = 1;
	$c->stash->{template} = 'event/view.tt';
}

sub add :Local :Args(0) {
	my ( $self, $c ) = @_;

	$c->forward('/assert_admin');

	$c->stash->{genres} = $c->model('DB::Genre');
	$c->stash->{formats} = $c->model('DB::Format');

	push $c->stash->{title}, 'Add Event';
	$c->stash->{template} = 'event/add.tt';

	if ($c->req->method eq 'POST') {
		$c->forward('/check_csrf_token');

		$c->form(
			start => [ 'NOT_BLANK', [qw/DATETIME_FORMAT RFC3339/] ],
			content_level => [ 'NOT_BLANK', [ 'IN_ARRAY', qw/E T M/ ] ],
			format => [
				'NOT_BLANK',
				[ 'NOT_DBIC_UNIQUE', $c->model('DB::Format'), 'id' ],
			],
			genre => [
				'NOT_BLANK',
				[ 'NOT_DBIC_UNIQUE', $c->model('DB::Genre'), 'id' ],
			],
			wc_min => [ qw/NOT_BLANK UINT/ ],
			wc_max => [ qw/NOT_BLANK UINT/ ],
			fic_dur    => [ qw/NOT_BLANK UINT/ ],
			prelim_dur => [ qw/NOT_BLANK UINT/ ],
			final_dur => [ qw/NOT_BLANK UINT/ ],
		);

		$c->forward('do_add') if !$c->form->has_error;
	}
}

sub do_add :Private {
	my ( $self, $c ) = @_;

	my $start = $c->form->valid('start');

	$c->stash->{event} = $c->model('DB::Event')->create({
		prompt        => 'TBD',
		genre_id      => $c->form->valid('genre'),
		format_id     => $c->form->valid('format'),
		content_level => $c->form->valid('content_level'),
		wc_min        => $c->form->valid('wc_min'),
		wc_max        => $c->form->valid('wc_max'),
	});

	$c->stash->{event}->add_to_users($c->user, { role => 'organiser' });

	my $writing = $c->stash->{event}->create_related('rounds', {
		name => 'writing',
		mode => 'fic',
		action => 'submit',
		start => $start,
		end => $start->clone->add(hours => $c->form->valid('fic_dur')),
	});

	my $prelim = $c->stash->{event}->create_related('rounds', {
		name => 'prelim',
		mode => 'fic',
		action => 'vote',
		start => $writing->end_leeway,
		end => $writing->end->clone->add(days => $c->form->valid('prelim_dur')),
	});

	my $final = $c->stash->{event}->create_related('rounds', {
		name => 'final',
		mode => 'fic',
		action => 'vote',
		start => $prelim->end,
		end => $prelim->end->clone->add(days => $c->form->valid('final_dur')),
	});

	$c->stash->{event}->reset_schedules;

	if ($c->req->param('notify_mailing_list')) {
		$c->run_after_request( sub { $c->forward('/event/_notify_mailing_list') });
	}

	$c->flash->{status_msg} = 'Event created';
	$c->res->redirect( $c->uri_for('/') );
}

sub fic :Chained('fetch') :PathPart('fic') :CaptureArgs(0) {
	my ( $self, $c ) = @_;

	$c->detach('/error', ['There is no fic component to this event.'])
		unless $c->stash->{event}->has('fic');

	push $c->stash->{title}, 'Fic';
}

sub art :Chained('fetch') :PathPart('art') :CaptureArgs(0) {
	my ( $self, $c ) = @_;

	$c->detach('/error', ['There is no art component to this event.'])
	unless $c->stash->{event}->has('art');

	push $c->stash->{title}, 'Art';
}

sub prompt :Chained('fetch') :PathPart('prompt') :CaptureArgs(0) {
	my ( $self, $c ) = @_;

	push $c->stash->{title}, 'Prompt';
}

sub vote :Chained('fetch') :PathPart('vote') :CaptureArgs(0) {
	my ( $self, $c ) = @_;

	$c->detach('/error', ['There is no voting component to this event.'])
		unless $c->stash->{event}->has('voting');

	push $c->stash->{title}, 'Vote';
}

sub rules :Chained('fetch') :PathPart('rules') :Args(0) {
	my ( $self, $c ) = @_;

	$c->stash->{template} = 'event/rules.tt';
	push $c->stash->{title}, 'Rules';
}

sub results :Private {
	my ( $self, $c ) = @_;

	$c->stash->{entrys} = $c->stash->{entrys}->search({}, {
		prefetch => [ qw/artist awards ratings/ ],
		order_by => [
			{ -asc => 'rank' },
			{ -asc => 'title' },
		],
	});

	$c->stash->{rounds} = [
		grep { $_->ratings->count }
			$c->stash->{event}->rounds->search(
				{
					mode => $c->stash->{mode},
					action => 'vote',
				},
				{
					order_by => { -desc => 'end' },
				}
			)
	];

	for my $round (@{ $c->stash->{rounds} }) {
		$round->{has_error} = $round->ratings->search({ error => { "!=" => undef }})->count;
	}

	$c->stash->{ratings} = $c->model('DB::Rating');

	push $c->stash->{title}, $c->string($c->stash->{mode} . 'Results');
	$c->stash->{template} = 'event/results.tt';
}

sub slates :Chained('fetch') :PathPart('slates') :Args(1) {
	my ($self, $c, $round) = @_;

	$c->detach('/default') unless grep { $round eq $_ } qw/prelim public private/;

	my $body = '';
	my $slates = $c->stash->{event}->vote_records->round($round)->slates;
	for my $slate (reverse sort { $#$a <=> $#$b } grep { $#$_ } @$slates) {
		$body .= join ' ', @$slate;
		$body .= "\n";
	}

	$c->res->content_type('text/plain; charset=utf-8');
	$c->res->body($body);
}

sub view :Chained('fetch') :PathPart('submissions') :Args(0) {
	my ( $self, $c ) = @_;

	$c->forward( $self->action_for('assert_organiser') );

	$c->detach('/default', [ 'Page under development...' ]);
}

sub edit :Chained('fetch') :PathPart('edit') :Args(0) {
	my ( $self, $c ) = @_;

	$c->forward( $self->action_for('assert_organiser') );

	if ($c->req->method eq 'POST') {
		$c->forward('/check_csrf_token');

		$c->form(
			user => [
				( $c->req->param('submit') =~ /Add/ ? 'NOT_BLANK' : () ),
				[ 'NOT_DBIC_UNIQUE', $c->model('DB::User')->verified, 'username' ],
			],
			blurb => [ [ 'LENGTH', 1, $c->config->{len}{max}{blurb} ] ],
			rules => [ [ 'LENGTH', 1, $c->config->{len}{max}{rules} ] ],
			content_level => [ 'NOT_BLANK', [ 'IN_ARRAY', qw/E T M/ ] ],
		);

		$c->forward('do_edit') if !$c->form->has_error;
	}

	$c->stash->{fillform} = {
		content_level => $c->stash->{event}->content_level,
		blurb => $c->stash->{event}->blurb,
		rules => $c->stash->{event}->custom_rules,
	};

	$c->stash->{staff} = [
		$c->stash->{event}->organisers->all,
		$c->stash->{event}->judges->all,
	];

	push $c->stash->{title}, 'Edit';
	$c->stash->{template} = 'event/edit.tt';
}

sub do_edit :Private {
	my ( $self, $c ) = @_;

	if ($c->req->param('submit') eq 'Edit details') {

		$c->stash->{event}->content_level( $c->form->valid('content_level') );
		$c->stash->{event}->update({
			blurb        => $c->form->valid('blurb'),
			custom_rules => $c->form->valid('rules'),
		});

		return $c->stash->{status_msg} = 'Details edited';
	}

	my $user = $c->model('DB::User')->verified
		->find({ username => $c->req->param('user') });

	if ($c->req->param('submit') eq 'Add organiser' && $user) {
		$c->forward( $c->controller('Root')->action_for('assert_admin') );

		eval { $c->stash->{event}->add_to_users($user, { role => 'organiser' }) };

		return $c->stash->{status_msg} = $@ ? '' : 'Organiser added';
	}

	if ($c->req->param('submit') eq 'Add judge' && $user) {
		return 0 unless $c->stash->{event}->private;

		eval { $c->stash->{event}->add_to_users($user, { role => 'judge' }) };

		return $c->stash->{status_msg} = $@ ? '' : 'Judge added';
	}
}

sub remove_judge :Chained('fetch') :PathPart('remove-judge') :Args(1) {
	my ( $self, $c, $user_id ) = @_;

	$c->forward( $self->action_for('assert_organiser') );

	$c->forward( $self->action_for('remove_user'), [ $user_id, 'judge' ] );
}

sub remove_organiser :Chained('fetch') :PathPart('remove-organiser') :Args(1) {
	my ( $self, $c, $user_id ) = @_;

	$c->forward( $c->controller('Root')->action_for('assert_admin') );

	$c->forward( $self->action_for('remove_user'), [ $user_id, 'organiser' ] );
}

sub remove_user :Private {
	my ( $self, $c, $user_id, $role ) = @_;

	my $junction = $c->model('DB::UserEvent')->find({
		user_id  => $user_id,
		event_id => $c->stash->{event}->id,
		role     => $role,
	});

	if (defined $junction) {
		$junction->delete;
		$c->flash->{status_msg} = sprintf "%s removed", ucfirst $role;
	}

	$c->res->redirect( $c->uri_for(
		$self->action_for('edit'), [ $c->stash->{event}->id_uri ]
	));
}

sub assert_organiser :Private {
	my ( $self, $c, $msg ) = @_;

	$msg //= 'You are not an organiser for this event.';
	$c->detach('/forbidden', [ $msg ]) unless
		$c->stash->{event}->is_organised_by( $c->user );
}

sub notify_mailing_list :Chained('fetch') :PathPart('notify_mailing_list') :Args(0) {
	my ( $self, $c ) = @_;

	$c->forward('/assert_admin');
	$c->run_after_request( sub{
		$c->forward('/event/_notify_mailing_list');
	});
	$c->forward('permalink');
}

sub _notify_mailing_list :Private {
	my ( $self, $c ) = @_;

	return 0 if !UNIVERSAL::isa($c->stash->{event}, 'WriteOff::Schema::Result::Event');

	my $rs = $c->model('DB::User')->mailing_list;

	$c->log->info( sprintf "Notifying mailing list of Event: %s - %s",
		$c->stash->{event}->id,
		$c->stash->{event}->prompt,
	);

	while (my $user = $rs->next) {
		$c->stash->{email} = {
			to           => $user->email,
			from         => $c->mailfrom,
			subject      => $c->config->{name} . " - New Event",
			template     => 'email/event.tt',
			content_type => 'text/html',
		};

		$c->forward( $c->view('Email::Template') );

		if (scalar @{ $c->error }) {
			$c->log->error($_) for @{ $c->error };
			$c->error(0);
		}
	}
}

sub set_prompt :Private {
	my ( $self, $c, $id ) = @_;

	my $e = $c->model('DB::Event')->find($id) or return 0;

	# In case of tie, we take one at random
	my @p = shuffle $e->prompts->all;
	my $best = $p[0];
	for my $p (@p) {
		if ($p->score > $best->score) {
			$best = $p;
		}
	}

	$e->update({ prompt => $best->contents });
}

sub check_rounds :Private {
	my ($self, $c) = @_;
}

sub tally_round :Private {
	my ( $self, $c, $eid, $rid ) = @_;

	my $e = $c->model('DB::Event')->find($eid) or return;
	my $r = $c->model('DB::Round')->find($rid) or return;

	$c->log->info("Tallying %s %s round for %s", $r->mode, $r->name, $e->prompt);
	$r->tally;
}

=head1 AUTHOR

Cameron Thornton E<lt>cthor@cpan.orgE<gt>

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
