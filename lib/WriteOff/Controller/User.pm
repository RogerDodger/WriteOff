package WriteOff::Controller::User;
use Moose;
use namespace::autoclean;
use feature ':5.10';
no warnings 'uninitialized';

BEGIN { extends 'Catalyst::Controller'; }

sub fetch :Chained('/') :PathPart('user') :CaptureArgs(1) :ActionClass('~Fetch') {
	my ( $self, $c, $id ) = @_;

	$c->stash->{user} = $c->model('DB::User')->find($id)
		or $c->detach('/default');
}

sub me :Local :Args(0) {
	my ( $self, $c ) = @_;

	$c->detach('/forbidden', ['You are not logged in.']) unless $c->user;

	$c->stash->{images}  = $c->user->obj->images;
	$c->stash->{storys}  = $c->user->obj->storys;
	$c->stash->{prompts} = $c->user->obj->prompts;

	push $c->stash->{title}, 'My Submissions';
	$c->stash->{template} = 'user/me.tt';
}

sub login :Local :Args(0) {
	my ( $self, $c ) = @_;

	$c->set_authenticated( $c->find_user({
		username => $c->req->params->{as} || $c->user->username
	}) ) if $c->check_user_roles('admin');

	$c->res->redirect( $c->uri_for('/') ) and return 0 if $c->user;

	push $c->stash->{title}, 'Login';
	$c->stash->{template} = 'user/login.tt';

	$c->forward('do_login') if $c->req->method eq 'POST';
}

sub do_login :Private {
	my ( $self, $c ) = @_;

	my $recently = DateTime->now->subtract(minutes => $c->config->{login}{timer});
	my $attempts = $c->model('DB::LoginAttempt')
			->search({ ip => $c->req->address })
			->created_after($recently)
			->count;

	if ($attempts >= $c->config->{login}{limit}) {
		$c->res->status(429);
		$c->stash->{error} = <<"EOF";
You have recently made a number of failed login attempts and for security
reasons have been temporarily blocked from making any more. Please try again
in around ${ \$c->config->{login}{timer} } minutes.
EOF
		$c->detach('/error');
	}

	my $success = $c->authenticate({
		password => $c->req->params->{Password} || '',
		username => $c->req->params->{Username} || '',
	});

	if ($success) {
		if (!$c->user->verified) {
			$c->flash->{error_msg} = 'Your account is not verified';
			$c->logout;
		}
	}
	else {
		$c->model('DB::LoginAttempt')->create({ ip => $c->req->address });
		$c->flash->{error_msg} = 'Bad username or password';
	}

	$c->res->redirect( $c->req->referer || $c->uri_for('/') );
}

sub logout :Local :Args(0) {
	my ( $self, $c ) = @_;
	$c->logout;
	$c->res->redirect( $c->uri_for('/') );
}

sub register :Local :Args(0) {
	my ( $self, $c ) = @_;

	$c->res->redirect( $c->uri_for('/') ) if $c->user;

	push $c->stash->{title}, 'Register';
	$c->stash->{template} = 'user/register.tt';

	$c->forward('/captcha_get');
	$c->forward('do_register') if $c->req->method eq 'POST';
}

sub do_register :Private {
	my ( $self, $c ) = @_;

	$c->req->params->{captcha} = $c->forward('/captcha_check');

	$c->form(
		username => [
			'NOT_BLANK',
			[ 'DBIC_UNIQUE', $c->model('DB::Virtual::Artist'), 'name' ],
			[ 'LENGTH', 2, $c->config->{len}{max}{user} ],
			[ 'REGEX', $c->config->{biz}{user}{regex} ]
		],
		password => [
			'NOT_BLANK',
			[ 'LENGTH', $c->config->{len}{min}{pass}, $c->config->{len}{max}{pass} ]
		],
		{ pass_confirm => [qw/password password2/] } => [ 'DUPLICATION' ],
		email => [
			'NOT_BLANK',
			'EMAIL_MX',
			[ 'DBIC_UNIQUE', $c->model('DB::User'), 'email' ]
		],
		timezone => [ 'NOT_BLANK', [ 'IN_ARRAY', $c->timezones ] ],
		captcha  => [ [ 'EQUAL_TO', 1 ] ],
	);

	if(!$c->form->has_error) {
		$c->stash->{user} = $c->model('DB::User')->create({
			username => $c->form->valid('username'),
			password => $c->form->valid('password'),
			email    => $c->form->valid('email'),
			timezone => $c->form->valid('timezone'),
			ip       => $c->req->address,
			mailme   => $c->req->params->{mailme} ? 1 : 0,
			last_mailed_at => DateTime->from_epoch(epoch => 0),
		});

		my $role = $c->model('DB::Role')->find({ role => 'user' });
		$c->stash->{user}->add_to_roles( $role );

		$c->log->info( sprintf 'User created: %s (%s)',
			$c->stash->{user}->username,
			$c->stash->{user}->email,
		);

		$c->stash->{mailtype} = { noun => 'verification', verb => 'verify' };
		$c->forward('send_email');
		$c->stash->{status_msg} = 'Registration successful!';
	}
}

sub settings :Local :Args(0) {
	my ( $self, $c ) = @_;

	$c->detach('/forbidden', [ 'You are not logged in.' ]) unless $c->user;

	$c->forward('do_settings') if $c->req->method eq 'POST';

	$c->stash->{fillform} = {
		timezone => $c->user->get('timezone'),
		mailme   => $c->user->get('mailme') ? 'on' : '',
	};

	$c->stash->{title} = 'User Settings';
	$c->stash->{template} = 'user/settings.tt';
}

sub do_settings :Private {
	my ( $self, $c ) = @_;

	$c->res->redirect( $c->req->referer || $c->uri_for( $c->action ) );

	$c->forward('/check_csrf_token');

	if( $c->req->params->{submit} eq 'Change password' ) {

		$c->req->params->{old} = $c->user->obj->discard_changes
			->check_password( $c->req->params->{old} );

		$c->form(
			password => [
				'NOT_BLANK',
				[ 'LENGTH', $c->config->{len}{min}{pass}, $c->config->{len}{max}{pass} ]
			],
			{ pass_confirm => [qw/password password2/] } => ['DUPLICATION'],
			old => [ 'NOT_BLANK' ],
		);

		if( !$c->form->has_error ) {
			$c->user->update({ password => $c->form->valid('password') });
			$c->flash->{status_msg} = 'Password changed successfully';
		}
		else {
			$c->flash->{error_msg} = 'Old Password is invalid';
		}
	}

	if( $c->req->params->{submit} eq 'Change settings' ) {

		my $tz = $c->req->param('timezone');

		if( $tz ~~ [ $c->timezones ] ) {
			$c->user->update({
				timezone => $tz,
				mailme   => $c->req->param('mailme') ? 1 : 0,
			});
			$c->persist_user;
			$c->flash->{status_msg} = 'Settings changed successfully';
		}
	}

}

sub verify :Local :Args(0) {
	my ($self, $c) = @_;

	$c->stash->{mailtype} = { noun => 'verification', verb => 'verify' };

	push $c->stash->{title}, 'Resend verification email';
	$c->stash->{template} = 'user/mailme.tt';

	if ($c->req->method eq 'POST') {
		$c->stash->{user} = $c->model('DB::User')->find({
			email => $c->req->param('email'),
		});
		if (defined $c->stash->{user}) {
			if ($c->stash->{user}->verified) {
				$c->stash->{verified} = 1;
			}
			else {
				$c->forward('send_email');
			}
		}
	}
}

sub do_verify :Chained('fetch') :PathPart('verify') :Args(1) {
	my ( $self, $c, $token ) = @_;

	if ($c->stash->{user}->verified) {
		$c->stash->{error} = 'This account is already verified';
		$c->detach('/error');
	}

	if ($c->stash->{user}->token eq $token) {
		$c->stash->{user}->update({ verified => 1 })->new_token;
		$c->set_authenticated( $c->find_user({ id => $c->stash->{user}->id }) );

		push $c->stash->{title}, 'Verification complete';
		$c->stash->{template} = 'user/verified.tt';
	}
	else {
		$c->res->redirect( $c->uri_for('/') );
	}
}

sub recover :Local :Args(0) {
	my ( $self, $c ) = @_;

	$c->stash->{mailtype} = { noun => 'recovery', verb => 'recover' };

	push $c->stash->{title}, 'Recover lost password';
	$c->stash->{template} = 'user/mailme.tt';

	if ($c->req->method eq 'POST') {
		$c->stash->{user} = $c->model('DB::User')->find({
			email => $c->req->param('email')
		});
		if (defined $c->stash->{user}) {
			if ($c->stash->{user}->verified) {
				$c->forward('send_email');
			}
			else {
				$c->stash->{unverified} = 1;
			}
		}
	}
}

sub do_recover :Chained('fetch') :PathPart('recover') :Args(1) {
	my ( $self, $c, $token ) = @_;

	if (!$c->stash->{user}->verified) {
		$c->stash->{error} = 'This account is not yet verified';
		$c->detach('/error');
	}

	if ($c->stash->{user}->token eq $token) {
		$c->stash->{pass} = $c->stash->{user}->new_password;
		$c->stash->{user}->new_token;

		push $c->stash->{title}, 'Recover password';
		$c->stash->{template} = 'user/recovered.tt';
	}
	else {
		$c->res->redirect( $c->uri_for('/') );
	}
}

sub send_email :Private {
	my ( $self, $c ) = @_;
	my $type = $c->stash->{mailtype}{noun} || '';

	state $template = {
		recovery     => 'email/recover.tt',
		verification => 'email/verify.tt',
	};
	state $subject = {
		recovery     => 'Password Recovery',
		verification => 'Verification',
	};

	if (!exists $template->{$type}) {
		$c->log->warn("Unknown email type '$type' given to User::send_email");
		return;
	}

	return unless defined $c->stash->{user};

	if ($c->stash->{user}->has_been_mailed_recently) {
		$c->res->status(429);
		$c->stash->{error} = <<EOF;
An email was not sent because that address has been emailed recently. Please
wait an hour and try again.
EOF
		$c->detach('/error');
	}

	$c->log->info("Sending $type email to " . $c->stash->{user}->email);

	$c->stash->{user}->new_token;

	$c->stash->{email} = {
		to           => $c->stash->{user}->email,
		from         => $c->mailfrom,
		subject      => join(' - ', $c->config->{name}, $subject->{$type}),
		template     => $template->{$type},
		content_type => 'text/html',
	};

	$c->forward( $c->view('Email::Template') );

	if (scalar @{ $c->error }) {
		$c->log->error($_) for @{ $c->error };
		$c->error(0);
		$c->res->status(500);
		$c->stash->{error} = "The $type email failed to send properly. "
		                   . "Please wait a few minutes, then try resending it.";
		$c->detach('/error');
	}
	else {
		$c->stash->{mailsent} = 1;
		$c->stash->{user}->update({ last_mailed_at => DateTime->now });
	}
}

sub list :Local :Args(0) {
	my ( $self, $c ) = @_;
	state $allowed = [ 'username', 'hugbox_score', 'prompt_skill', 'created' ];

	if (defined $c->req->param('term') && $c->req->param('term') eq '') {
		return $c->res->redirect( $c->uri_for( $c->action ) );
	}

	$c->stash->{users} = $c->model('DB::User')->search(
	{
		'me.username' => { like => '%' . $c->req->param('term') . '%' },
		'me.verified' => 1,
	},
	{
		order_by => {
			$c->req->param('o') eq 'desc' ? '-desc' : '-asc',
			$c->req->param('q') ~~ $allowed ? $c->req->param('q') : undef
		}
	}
	)->with_stats;

	if( $c->req->param('view') eq 'json' ) {
		$c->stash->{json} = [
			$c->stash->{users}->get_column('username')->all
		];

		$c->detach( $c->view('JSON') );
	}

	push $c->stash->{title}, 'Users';
	$c->stash->{template} = 'user/list.tt';
}

=head1 AUTHOR

Cameron Thornton E<lt>cthor@cpan.orgE<gt>

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
