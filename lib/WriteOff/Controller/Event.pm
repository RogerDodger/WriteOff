package WriteOff::Controller::Event;
use Moose;
use List::Util qw/shuffle/;
use WriteOff::Award qw/:all/;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller'; }

sub fetch :Chained('/') :PathPart('event') :CaptureArgs(1) :ActionClass('~Fetch') {}

sub permalink :Chained('fetch') :PathPart('') :Args(0) {
	my ( $self, $c ) = @_;

	$c->stash->{event}{autoexpand} = 1;
	$c->stash->{template} = 'event/view.tt';
}

sub add :Local :Args(0) {
	my ( $self, $c ) = @_;

	$c->forward('/assert_admin');

	$c->stash->{genres} = $c->model('DB::Genre');
	$c->stash->{formats} = $c->model('DB::Format');

	# These options probably aren't necessary anymore
	$c->req->params->{prompt_type} = 'approval';
	$c->req->params->{prompt} = 'TBD';

	push $c->stash->{title}, 'Add Event';
	$c->stash->{template} = 'event/add.tt';

	if ($c->req->method eq 'POST') {
		$c->forward('/check_csrf_token');

		my $p = $c->req->params;
		$c->form(
			start => [ 'NOT_BLANK', [qw/DATETIME_FORMAT RFC3339/] ],
			prompt => [ [ 'LENGTH', 1, $c->config->{len}{max}{prompt} ] ],
			content_level => [ 'NOT_BLANK', [ 'IN_ARRAY', qw/E T M/ ] ],
			prompt_type => [ [ 'IN_ARRAY', qw/faceoff approval/ ] ],
			organiser => [
				'NOT_BLANK',
				[ 'NOT_DBIC_UNIQUE', $c->model('DB::User')->verified, 'username' ],
			],
			format => [
				'NOT_BLANK',
				[ 'NOT_DBIC_UNIQUE', $c->model('DB::Format'), 'id' ],
			],
			genre => [
				'NOT_BLANK',
				[ 'NOT_DBIC_UNIQUE', $c->model('DB::Genre'), 'id' ],
			],
			wc_min => [ $p->{has_fic} ? qw/NOT_BLANK UINT/ : () ],
			wc_max => [ $p->{has_fic} ? qw/NOT_BLANK UINT/ : () ],
			fic_dur     => [ $p->{has_fic}    ? qw/NOT_BLANK UINT/ : () ],
			public_dur  => [ $p->{has_public} ? qw/NOT_BLANK UINT/ : () ],
			art_dur     => [ $p->{has_art}    ? qw/NOT_BLANK UINT/ : () ],
			prelim_dur  => [ $p->{has_prelim} ? qw/NOT_BLANK UINT/ : () ],
			private_dur => [ $p->{has_judges} ? qw/NOT_BLANK UINT/ : () ],
		);

		$c->forward('do_add') if !$c->form->has_error;
	}
}

sub do_add :Private {
	my ( $self, $c ) = @_;

	my $p  = $c->req->params;
	my $dt = $c->form->valid('start');

	my $leeway = $c->model('DB::Event')->result_class->LEEWAY;

	my %row;
	if (exists $p->{prompt_type}) {
		$row{prompt_type} = $p->{prompt_type};
	}

	if ($p->{has_art}) {
		$row{art}     = $dt->clone;
		$row{art_end} = $dt->add( hours => $c->form->valid('art_dur') )->clone;
	}

	if ($p->{has_fic}) {
		$row{wc_min}  = $c->form->valid('wc_min');
		$row{wc_max}  = $c->form->valid('wc_max');
		if ($row{wc_min} > $row{wc_max}) {
			($row{wc_min}, $row{wc_max}) = ($row{wc_max}, $row{wc_min});
		}

		$row{fic}     = $dt->clone;
		$row{fic_end} = $dt->add(hours => $c->form->valid('fic_dur'))->clone;
	}

	if ($p->{has_prelim}) {
		$row{prelim} = $dt->clone;
		$row{prelim}->add(minutes => $leeway);
		$dt->add(days => $c->form->valid('prelim_dur'));
	}

	if ($p->{has_public}) {
		$row{public} = $dt->clone;
		$row{public}->add(minutes => $leeway) if !$p->{has_prelim};
		$dt->add(days => $c->form->valid('public_dur'));
	}

	if ($p->{has_judges}) {
		$row{private} = $dt->clone;
		$row{private}->add(minutes => $leeway) if !$p->{has_prelim} && !$p->{has_public};
		$dt->add(days => $c->form->valid('private_dur'));
	}

	$row{end} = $dt->clone;
	$row{prompt} = $c->form->valid('prompt') || 'TBD';
	$row{genre_id} = $c->form->valid('genre');
	$row{format_id} = $c->form->valid('format');

	$c->stash->{event} = $c->model('DB::Event')->create(\%row);
	$c->stash->{event}->set_content_level( $c->form->valid('content_level') );

	my $user = $c->model('DB::User')->find({ username => $c->form->valid('organiser') });
	$c->stash->{event}->add_to_users($user, { role => 'organiser' });

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
		unless $c->stash->{event}->fic;

	push $c->stash->{title}, 'Fic';
}

sub art :Chained('fetch') :PathPart('art') :CaptureArgs(0) {
	my ( $self, $c ) = @_;

	$c->detach('/error', ['There is no art component to this event.'])
		unless $c->stash->{event}->art;

	push $c->stash->{title}, 'Art';
}

sub prompt :Chained('fetch') :PathPart('prompt') :CaptureArgs(0) {
	my ( $self, $c ) = @_;

	$c->detach('/error', ['There is no prompt for this event.'])
		unless $c->stash->{event}->has_prompt;

	push $c->stash->{title}, 'Prompt';
}

sub vote :Chained('fetch') :PathPart('vote') :CaptureArgs(0) {
	my ( $self, $c ) = @_;

	$c->detach('/error', ['There is no voting component to this event.'])
		unless $c->stash->{event}->has_results;

	push $c->stash->{title}, 'Vote';
}

sub rules :Chained('fetch') :PathPart('rules') :Args(0) {
	my ( $self, $c ) = @_;

	$c->stash->{start} = $c->stash->{event}->has_prompt
		? 'the prompt is released'
		: 'the event starts';

	$c->stash->{template} = 'event/rules.tt';
	push $c->stash->{title}, 'Rules';
}

sub results :Private {
	my ( $self, $c ) = @_;

	$c->stash->{items} = $c->stash->{items}->search({}, {
		prefetch => [ qw/artist artist_awards/ ],
		order_by => [
			{ -asc => 'rank' },
			{ -asc => 'title' },
		],
	});

	push $c->stash->{title}, 'Results';
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

	my $e = $c->stash->{event};

	$c->stash->{storys}  = $e->storys->metadata->order_by('created');
	$c->stash->{images}  = $e->images->metadata->order_by('created');
	$c->stash->{prompts} = $e->prompts->order_by('created');
	$c->stash->{records} = $e->vote_records->filled->ordered;

	push $c->stash->{title}, 'Submissions';
	$c->stash->{template} = 'user/me.tt';
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
			timezone     => $user->timezone,
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

	my @p = shuffle $e->prompts->all;
	my $best = $p[0];
	if ($e->prompt_type eq 'approval') {
		for my $p (@p) {
			if ($p->approvals > $best->approvals) {
				$best = $p;
			}
		}
	}
	elsif ($e->prompt_type eq 'faceoff') {
		for my $p (@p) {
			if ($p->rating > $best->rating) {
				$best = $p;
			}
		}
	}

	$e->update({ prompt => $best->contents });
}

sub prelim_distr :Private {
	my ( $self, $c, $id ) = @_;

	my $e = $c->model('DB::Event')->find($id) or return 0;

	$e->prelim_distr($c->config->{work});
}

sub public_distr :Private {
	my ($self, $c, $id) = @_;

	my $e = $c->model('DB::Event')->find($id) or return 0;

	$e->public_distr($c->config->{work});
}

sub judge_distr :Private {
	my ( $self, $c, $id ) = @_;

	my $e = $c->model('DB::Event')->find($id) or return 0;

	$e->judge_distr( $c->config->{judge_distr_size} );
}

sub tally_results :Private {
	my ( $self, $c, $id ) = @_;

	my $e = $c->model('DB::Event')->find($id) or return 0;

	$c->log->info(sprintf "Tallying results for: Event %d - %s", $e->id, $e->prompt);

	$e->tally;
}

=head1 AUTHOR

Cameron Thornton E<lt>cthor@cpan.orgE<gt>

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
