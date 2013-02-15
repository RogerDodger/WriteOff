package WriteOff::Controller::Event;
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller'; }

=head1 NAME

WriteOff::Controller::Event - Catalyst Controller

=head1 DESCRIPTION

Chained actions for grabbing an event and determining if the requested event 
part allows submissions at the current time.


=head1 METHODS

=head2 index :PathPart('event') :Chained('/') :CaptureArgs(1)

Grabs an event.

=cut

sub index :PathPart('event') :Chained('/') :CaptureArgs(1) {
    my ( $self, $c, $arg ) = @_;
	
	(my $id = $arg) =~ s/^\d+\K.*//;
	$c->stash->{event} = $c->model('DB::Event')->find($id) or 
		$c->detach('/default');
	
	if( $arg ne $c->stash->{event}->id_uri ) {
		my $url = $c->uri_for( $c->action, [ $c->stash->{event}->id_uri ] );
		$c->res->redirect($url);
		$c->detach();
	}
	
	push $c->stash->{title}, $c->stash->{event}->prompt;
}

=head2 permalink :Chained('index') :PathPart('') :Args(0)

Redirects to the event overview in the event listings.

=cut

sub permalink :Chained('index') :PathPart('') :Args(0) {
	my ( $self, $c ) = @_;

	$c->res->redirect(
		$c->uri_for(
			$c->controller('Root')->action_for(
				$c->model('DB::Event')->active->find( $c->stash->{event}->id ) ?
				'index' : 'archive',
			)
		)
		. "#" . $c->stash->{event}->id_uri
	);
}

=head2 add :Local :Args(0)

Adds an event.

=cut

sub add :Local :Args(0) {
	my ( $self, $c ) = @_;
	
	$c->forward('/assert_admin');
	
	$c->stash->{template} = 'event/add.tt';
	
	if($c->req->method eq 'POST') {
	
		$c->forward('/check_csrf_token');
		
		my $p = $c->req->params; 
		$c->form(
			start => [ 'NOT_BLANK', [qw/DATETIME_FORMAT RFC3339/] ],
			prompt => [ [ 'LENGTH', 1, $c->config->{len}{max}{prompt} ] ],
			content_level => [ 'NOT_BLANK', [ 'IN_ARRAY', qw/E T M/ ] ],
			organiser => [ 
				'NOT_BLANK',
				[ 'NOT_DBIC_UNIQUE', $c->model('DB::User')->verified, 'username' ],
			],
			wc_min => [ qw/NOT_BLANK UINT/, [ 'LESS_THAN', $c->req->param('wc_max') ] ],
			wc_max => [ qw/NOT_BLANK UINT/ ],
			fic_dur     => [ qw/NOT_BLANK UINT/ ],
			public_dur  => [ qw/NOT_BLANK UINT/ ],
			art_dur     => [ $p->{has_art}    ? qw/NOT_BLANK UINT/ : () ],
			prelim_dur  => [ $p->{has_prelim} ? qw/NOT_BLANK UINT/ : () ],
			private_dur => [ $p->{has_judges} ? qw/NOT_BLANK UINT/ : () ]
		);
		
		$c->forward('do_add') if !$c->form->has_error;
	}
}

sub do_add :Private {
	my ( $self, $c ) = @_;
	
	my $p  = $c->req->params; 
	my $dt = $c->form->valid('start');
	
	my $leeway = $c->model('DB::Event')->result_class->leeway;
	my $interim = $c->config->{interim};
	
	my %row;
	$row{start} = $dt->clone;

	if( $row{has_prompt} = defined $p->{has_prompt} || 0 ) {
		$row{prompt_voting} = $dt->add( minutes => $interim )->clone;
		$dt->add( minutes => $interim );
	}
	else {
		# Need to set this to something, since I (stupidly) made the row NOT NULL
		$row{prompt_voting} = $dt; 
	}
	
	if( $p->{has_art} ) {
		$row{art}     = $dt->clone;
		$row{art_end} = $dt->add( hours => $c->form->valid('art_dur') )->clone;
	} 
	
	$row{fic}     = $dt->clone;
	$row{fic_end} = $dt->add( hours => $c->form->valid('fic_dur') )->clone;
	
	if( $p->{has_prelim} ) {
		$row{prelim} = $dt->clone->add( minutes => $leeway );
		$row{public} = $dt->add( days => $c->form->valid('prelim_dur') )->clone;
	}
	else {
		$row{public} = $dt->clone->add( minutes => $leeway );
	}
	
	if( $p->{has_judges} ) {
		$row{private} = $dt->add( days => $c->form->valid('public_dur')  )->clone;
		$row{end}     = $dt->add( days => $c->form->valid('private_dur') )->clone;
	}
	else {
		$row{end} = $dt->add( days => $c->form->valid('public_dur') )->clone;
	}
	
	$row{prompt} = $c->form->valid('prompt') || 'TBD';
	$row{wc_min} = $c->form->valid('wc_min');
	$row{wc_max} = $c->form->valid('wc_max');
	
	$c->stash->{event} = $c->model('DB::Event')->create(\%row);
	$c->stash->{event}->set_content_level( $c->form->valid('content_level') );

	my $user = $c->model('DB::User')->find({ username => $c->form->valid('organiser') });
	$c->stash->{event}->add_to_users($user, { role => 'organiser' });

	$c->stash->{event}->reset_schedules;
	
	if( $c->req->param('notify_mailing_list') ) {
		$c->run_after_request( sub { $c->forward('/event/_notify_mailing_list') });
	}
	
	$c->flash->{status_msg} = 'Event created';
	$c->res->redirect( $c->uri_for('/') );
}

sub fic :PathPart('fic') :Chained('index') :CaptureArgs(0) {
	my ( $self, $c ) = @_;
	
	push $c->stash->{title}, 'Fic';
}

sub art :PathPart('art') :Chained('index') :CaptureArgs(0) {
	my ( $self, $c ) = @_;

	$c->detach('/error', ['There is no art component to this event.']) 
		unless $c->stash->{event}->art;
		
	push $c->stash->{title}, 'Art';
}

sub prompt :PathPart('prompt') :Chained('index') :CaptureArgs(0) {
	my ( $self, $c ) = @_;

	$c->detach('/error', ['There is no prompt for this event.'])
		unless $c->stash->{event}->has_prompt;
	
	push $c->stash->{title}, 'Prompt';
}

sub vote :PathPart('vote') :Chained('index') :CaptureArgs(0) {
	my ( $self, $c ) = @_;
	
	push $c->stash->{title}, 'Vote';
}

sub rules :PathPart('rules') :Chained('index') :Args(0) {
	my ( $self, $c ) = @_;

	$c->stash->{start} = $c->stash->{event}->has_prompt ? 'the prompt is released' : 'the event starts';
	
	$c->stash->{template} = 'event/rules.tt';
	push $c->stash->{title}, 'Rules';
}

sub results :PathPart('results') :Chained('index') :Args(0) {
	my ( $self, $c ) = @_;
	
	$c->stash->{awards} = { map { $_->name => $_ } $c->model('DB::Award')->all };

	$c->stash->{judge_records} = 
		$c->stash->{event}->vote_records->filled->judge_records;

	push $c->stash->{title}, 'Results';
	$c->stash->{template} = 'event/results.tt';
}

sub view :PathPart('submissions') :Chained('index') :Args(0) {
	my ( $self, $c ) = @_;
	
	$c->forward( $self->action_for('assert_organiser') );
	
	$c->stash->{storys}  = $c->stash->{event}->storys->metadata;
	$c->stash->{images}  = $c->stash->{event}->images->metadata;
	$c->stash->{prompts} = $c->stash->{event}->prompts;
	$c->stash->{records} = $c->stash->{event}->vote_records->filled->ordered->with_stats;
	
	push $c->stash->{title}, 'Submissions';
	$c->stash->{template} = 'user/me.tt';
}

sub edit :PathPart('edit') :Chained('index') :Args(0) {
	my ( $self, $c ) = @_;
	
	$c->forward( $self->action_for('assert_organiser') );
		
	if( $c->req->method eq 'POST' ) {
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
	
	if( $c->req->param('submit') eq 'Edit details' ) {
	
		$c->stash->{event}->content_level( $c->form->valid('content_level') );
		$c->stash->{event}->update({ 
			blurb        => $c->form->valid('blurb'),
			custom_rules => $c->form->valid('rules'),
		});
			
		return $c->stash->{status_msg} = 'Details edited';
	}
	
	my $user = $c->model('DB::User')->verified
		->find({ username => $c->req->param('user') });
	
	if( $c->req->param('submit') eq 'Add organiser' && $user ) {
		$c->forward( $c->controller('Root')->action_for('assert_admin') );
		
		eval { $c->stash->{event}->add_to_users($user, { role => 'organiser' }) };
		
		return $c->stash->{status_msg} = $@ ? '' : 'Organiser added';
	}
	
	if( $c->req->param('submit') eq 'Add judge' && $user ) {
		return 0 unless $c->stash->{event}->private;
		
		eval { $c->stash->{event}->add_to_users($user, { role => 'judge' }) };
		
		return $c->stash->{status_msg} = $@ ? '' : 'Judge added';
	}
}

sub remove_judge :PathPart('remove-judge') :Chained('index') :Args(1) {
	my ( $self, $c, $user_id ) = @_;
	
	$c->forward( $self->action_for('assert_organiser') );
	
	$c->forward( $self->action_for('remove_user'), [ $user_id, 'judge' ] );
}

sub remove_organiser :PathPart('remove-organiser') :Chained('index') :Args(1) {
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
	
	if( defined $junction ) {
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

sub notify_mailing_list :Chained('index') :PathPart('notify_mailing_list') {
	my ( $self, $c ) = @_;

	$c->forward('/assert_admin');
	$c->run_after_request( sub{ 
		$c->forward('/event/_notify_mailing_list');
	});
	$c->forward('permalink');
}

sub _notify_mailing_list :Private {
	my ( $self, $c ) = @_;
	
	return 0 unless eval { 
		$c->stash->{event}->isa('WriteOff::Schema::Result::Event');
	};
	
	my $rs = $c->model('DB::User')->mailing_list;

	#Debugging
	$rs = $rs->search({ username => 'RogerDodger' });
	
	$c->log->info( sprintf "Notifying mailing list of Event: %s - %s",
		$c->stash->{event}->id,
		$c->stash->{event}->prompt,
	);
	
	while ( my $user = $rs->next ) {
		$c->stash->{email} = {
			to           => $user->email,
			from         => $c->mailfrom,
			subject      => $c->config->{name} . " - New Event",
			template     => 'email/event.tt',
			content_type => 'text/html',
			timezone     => $user->timezone,
		};
	
		$c->forward( $c->view('Email::Template') );
	}
}

sub set_prompt :Private {
	my ( $self, $c, $id ) = @_;
	
	my $e = $c->model('DB::Event')->find($id) or return 0;
	my $p = $e->prompts->search(undef, { order_by => { -desc => 'rating' } });
	
	$e->update({ prompt => $p->first->contents });
}

sub prelim_distr :Private {
	my ( $self, $c, $id ) = @_;
	
	my $e = $c->model('DB::Event')->find($id) or return 0;
	
	$e->prelim_distr( $c->config->{prelim_distr_size} );
}

sub judge_distr :Private {
	my ( $self, $c, $id ) = @_;

	my $e = $c->model('DB::Event')->find($id) or return 0;
	
	$e->judge_distr( $c->config->{judge_distr_size} );
}

sub tally_results :Private {
	my ( $self, $c, $id ) = @_;

	my $e = $c->model('DB::Event')->find($id) or return 0;
	
	$c->log->info( sprintf "Tallying results for: Event %02d - %s", 
		$e->id, $e->prompt
	);
	
	$c->model('DB::Artist')->deal_awards_and_scores( $e->storys_rs );
	$c->model('DB::Artist')->deal_awards_and_scores( $e->images_rs ) if $e->art;
	$c->model('DB::Artist')->recalculate_scores;
}

=head1 AUTHOR

Cameron Thornton E<lt>cthor@cpan.orgE<gt>

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
