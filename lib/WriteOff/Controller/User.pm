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

	$c->stash->{images}  = $c->user->images->order_by('created');
	$c->stash->{storys}  = $c->user->storys->order_by('created');
	$c->stash->{prompts} = $c->user->prompts->order_by('created');

	push $c->stash->{title}, 'My Submissions';
	$c->stash->{template} = 'user/me.tt';
}

sub login :Local :Args(0) {
	my ( $self, $c ) = @_;

	if ($c->user->admin && exists $c->req->params->{as}) {
		$c->user(
			$c->model('DB::User')->find({ username => $c->req->params->{as} })
		);
	}

	$c->detach('/error', [ 'You are already logged in.' ]) if $c->user;

	push $c->stash->{title}, 'Login';
	$c->stash->{template} = 'user/login.tt';

	$c->forward('do_login') if $c->req->method eq 'POST';
}

sub do_login :Private {
	my ( $self, $c ) = @_;

	my $cache = $c->cache(backend => 'login-attempts');
	my $key = $c->req->address;
	my $attempts = $cache->get($key) // 0;

	if (++$attempts > $c->config->{login}{limit}) {
		$c->res->status(429);
		$c->stash->{error} = <<"EOF";
You have recently made a number of failed login attempts and for security
reasons have been temporarily blocked from making any more. Please try again
in around ${ \$c->config->{login}{timer} }.
EOF
		$c->detach('/error');
	}

	if ($c->authenticate(@{$c->req->params}{qw/Username Password/})) {
		if (!$c->user->verified) {
			$c->flash->{error_msg} = 'Your account is not verified';
			$c->logout;
		}
	}
	else {
		$cache->set($key, $attempts);
		$c->flash->{error_msg} = 'Bad username or password';
	}

	$c->res->redirect( $c->uri_for('/') );
}

sub logout :Local :Args(0) {
	my ( $self, $c ) = @_;
	$c->logout;
	$c->res->redirect( $c->req->referer || $c->uri_for('/') );
}

sub register :Local :Args(0) {
	my ( $self, $c ) = @_;

	$c->res->redirect( $c->uri_for('/') ) if $c->user;

	$c->stash->{timezones} = [ WriteOff::DateTime->timezones ];
	$c->forward('/captcha_get');

	push $c->stash->{title}, 'Register';
	$c->stash->{template} = 'user/register.tt';

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
		timezone => [ 'NOT_BLANK', [ 'IN_ARRAY', WriteOff::DateTime->timezones ] ],
		captcha  => [ [ 'EQUAL_TO', 1 ] ],
	);

	if (!$c->form->has_error) {
		$c->stash->{user} = $c->model('DB::User')->create({
			username => $c->form->valid('username'),
			password => $c->form->valid('password'),
			email    => $c->form->valid('email'),
			timezone => $c->form->valid('timezone'),
			ip       => $c->req->address,
			mailme   => $c->req->params->{mailme} ? 1 : 0,
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

sub prefs :Local :Args(0) {
	my ( $self, $c ) = @_;

	$c->detach('/forbidden', [ 'You are not logged in.' ]) unless $c->user;

	$c->stash->{timezones} = [ WriteOff::DateTime->timezones ];

	$c->forward('do_prefs') if $c->req->method eq 'POST';

	$c->stash->{fillform} = {
		timezone => $c->user->timezone,
		mailme   => $c->user->mailme ? 'on' : '',
	};

	push $c->stash->{title}, qw/User Preferences/;
	$c->stash->{template} = 'user/prefs.tt';
}

sub do_prefs :Private {
	my ( $self, $c ) = @_;

	$c->forward('/check_csrf_token');

	my $tz = $c->req->param('timezone');

	if (grep { $_ eq $tz } WriteOff::DateTime->timezones) {
		$c->user->update({
			timezone => $tz,
			mailme   => $c->req->param('mailme') ? 1 : 0,
		});
		$c->flash->{status_msg} = 'Preferences changed successfully';
	}

	$c->res->redirect($c->req->referer || $c->uri_for($c->action));
}

sub credentials :Path('credentials') :Args(0) {
	my ($self, $c) = @_;

	$c->detach('/forbidden', [ 'You are not logged in.' ]) unless $c->user;

	my $key = $c->stash->{key} = $c->req->param('key') || '';
	if ($key ne 'password' && $key ne 'email') {
		$c->detach('/default');
	}

	if ($c->req->method eq 'POST') {
		$c->forward('do_credentials');
	}

	push $c->stash->{title}, qw/User Credentials/;
	$c->stash->{template} = 'user/credentials.tt';
}

sub do_credentials :Private {
	my ($self, $c) = @_;

	$c->forward('/check_csrf_token');

	my $user = $c->stash->{user} = $c->user;

	if (!$user->check_password(scalar $c->req->param('password'))) {
		$c->flash->{error_msg} = 'Current password is invalid';
	}
	elsif ($c->stash->{key} eq 'password') {
		my $new1 = $c->req->param('newpassword')  // '';
		my $new2 = $c->req->param('confirmpassword') // '';

		if ($new1 eq $new2) {
			$c->user->update({ password => $new1 });
			$c->flash->{status_msg} = 'Password changed successfully';
		}
		else {
			$c->flash->{error_msg} = 'Passwords do not match';
		}
	}
	elsif ($c->stash->{key} eq 'email') {
		my $mailto = $c->stash->{mailto} = $c->req->param('email');

		if (!defined $c->model('DB::User')->find({ email => $mailto })) {
			$c->stash->{mailtype}{noun} = 'relocation';
			$c->forward('send_email');
			$c->flash->{status_msg} =
				"Verification email sent to <strong>$mailto</strong>";
		}
		else {
			$c->flash->{error_msg} = 'A user with that email address already exists';
		}
	}

	$c->res->redirect($c->req->referer || $c->uri_for($c->action));
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
	my ($self, $c, $hash, $token) = @_;

	if ($token = $c->stash->{user}->find_token('verification', $hash)) {
		$c->stash->{user}->update({ verified => 1 });
		$c->flash->{status_msg} = 'Account verified successfully';
	}
	elsif ($token = $c->stash->{user}->find_token('relocation', $hash)) {
		$c->stash->{user}->update({ email => $token->address });
		$c->flash->{status_msg} = 'Email changed successfully';
	}
	else {
		return $c->detach('/default');
	}

	$token->delete;
	$c->user($c->stash->{user});
	$c->res->redirect('/');
}

sub recover :Local :Args(0) {
	my ( $self, $c ) = @_;

	return $c->res->redirect('/') if $c->user;

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

	if (my $token = $c->stash->{user}->find_token('recovery', $token)) {
		$token->delete;
		$c->stash->{pass} = $c->stash->{user}->new_password;

		push $c->stash->{title}, 'Password Recovery';
		$c->stash->{template} = 'user/recovered.tt';
	}
	else {
		$c->res->redirect('/');
	}
}

sub send_email :Private {
	my ( $self, $c ) = @_;
	my $type = $c->stash->{mailtype}{noun} || '';

	state $template = {
		relocation   => 'email/relocate.tt',
		recovery     => 'email/recover.tt',
		verification => 'email/verify.tt',
	};
	state $subject = {
		relocation   => 'Email Change',
		recovery     => 'Password Recovery',
		verification => 'Verification',
	};

	if (!exists $template->{$type}) {
		$c->log->warn("Unknown email type '$type' given to User::send_email");
		return;
	}

	return unless defined $c->stash->{user};

	my $mailto = $c->stash->{mailto} || $c->stash->{user}->email;
	my $cache  = $c->cache(backend => 'recent-emails');

	if ($cache->get($mailto)) {
		$c->res->status(429);
		$c->stash->{error} = <<EOF;
An email was not sent because that address has been emailed recently. Please
wait 10 minutes and try again.
EOF
		$c->detach('/error');
	}

	$c->log->info("Sending $type email to $mailto");

	$c->stash->{token} = $c->stash->{user}->new_token($type, $mailto);

	$c->stash->{email} = {
		to           => $mailto,
		from         => $c->mailfrom,
		subject      => join(' - ', $c->config->{name}, $subject->{$type}),
		template     => $template->{$type},
		content_type => 'text/html',
	};

	$c->forward('View::Email::Template');

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
		$cache->set($mailto, 1);
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
