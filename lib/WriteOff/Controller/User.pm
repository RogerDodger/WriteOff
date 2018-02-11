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

sub artists :Local :Args(0) {
	my ($self, $c) = @_;

	$c->detach('/forbidden', [ $c->string('notUser') ]) unless $c->user;

	$c->stash->{artists} = $c->user->artists->search({}, {
		order_by => 'created',
	});

	if ($c->req->method eq 'POST') {
		for my $artist ($c->stash->{artists}->all) {
			$artist->active(!!$c->req->param('active-' . $artist->id));
			$artist->update;
		}
	}
}

sub login :Local :Args(0) {
	my ( $self, $c ) = @_;

	$c->detach('/error', [ $c->string('areUser') ]) if $c->user;

	push @{ $c->stash->{title} }, 'Login';
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
		$c->stash->{error} = $c->string('loginLimited', $c->config->{login}{timer});
		$c->detach('/error');
	}

	if ($c->authenticate(@{$c->req->params}{qw/Username Password/})) {
		if (!$c->user->verified) {
			$c->flash->{error_msg} = 'Your account is not verified';
			$c->logout;
		}
		$c->res->redirect($c->req->param('referer') // $c->uri_for('/'));
	}
	else {
		$cache->set($key, $attempts);
		$c->stash->{error_msg} = 'Bad username or password';
	}
}

sub logout :Local :Args(0) {
	my ( $self, $c ) = @_;
	$c->logout;
	$c->res->redirect( $c->req->referer || $c->uri_for('/') );
}

sub register :Local :Args(0) {
	my ( $self, $c ) = @_;

	$c->res->redirect( $c->uri_for('/') ) if $c->user;

	$c->forward('/captcha_get');

	push @{ $c->stash->{title} }, 'Register';
	$c->stash->{template} = 'user/register.tt';

	$c->forward('do_register') if $c->req->method eq 'POST';
}

sub do_register :Private {
	my ( $self, $c ) = @_;

	$c->req->params->{captcha} = $c->forward('/captcha_check');

	$c->form(
		username => [
			'NOT_BLANK',
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
		# captcha  => [ [ 'EQUAL_TO', 1 ] ],
	);

	if (!$c->form->has_error) {
		$c->stash->{user} = $c->model('DB::User')->create({
			name            => $c->form->valid('username'),
			name_canonical  => CORE::fc $c->form->valid('username'),
			password        => $c->form->valid('password'),
			email           => $c->form->valid('email'),
			email_canonical => CORE::fc $c->form->valid('email'),
		});

		$c->stash->{user}->update({
			active_artist =>
				$c->stash->{user}->create_related('artists', {
					name => $c->stash->{user}->name,
					name_canonical => $c->stash->{user}->name_canonical,
				})
		});

		$c->log->info( sprintf 'User created: %s (%s)',
			$c->stash->{user}->name,
			$c->stash->{user}->email,
		);

		$c->stash->{mailtype} = { noun => 'verification', verb => 'verify' };
		$c->forward('send_email');
		$c->stash->{status_msg} = 'Registration successful!';
	}
}

sub prefs :Local :Args(0) {
	my ( $self, $c ) = @_;

	$c->detach('/forbidden', [ $c->string('notUser') ]) unless $c->user;

	$c->stash->{triggers} = $c->model('DB::EmailTrigger');
	$c->stash->{formats} = $c->model('DB::Format');
	$c->stash->{genres} = $c->model('DB::Genre');

	$c->forward('do_prefs') if $c->req->method eq 'POST';

	$c->stash->{fillform} = {
		font => $c->user->font,
		map {
			my $k = $_;
			my $m = "sub_${_}s";
			my $i = "${_}_id";
			map {
				$k . $_->$i, 'on'
			} $c->user->$m->all;
		} qw/trigger genre format/,
	};

	push @{ $c->stash->{title} }, $c->string('preferences');
	$c->stash->{template} = 'user/prefs.tt';
}

sub do_prefs :Private {
	my ( $self, $c ) = @_;

	$c->forward('/check_csrf_token');

	$c->user->update({
		font => ($c->req->param('font') // '') =~ /^(serif|sans-serif)$/ ? $1 : 'serif',
	});

	for my $k (qw/trigger genre format/) {
		my $m = "sub_${k}s";
		$c->user->$m->delete;
		$c->model('DB::Sub' . ucfirst $k)->populate([
			map {{
				user_id   => $c->user->id,
				"${k}_id" => $_->id,
			}}
			grep {
				$c->req->param($k . $_->id)
			}
			$c->stash->{$k . 's'}->all,
		]);
	}

	$c->flash->{status_msg} = 'Preferences changed successfully';

	$c->res->redirect($c->req->referer || $c->uri_for($c->action));
}

sub credentials :Path('credentials') :Args(0) {
	my ($self, $c) = @_;

	$c->detach('/forbidden', [ $c->string('notUser') ]) unless $c->user;

	my $key = $c->stash->{key} = $c->req->param('key') || '';
	if ($key ne 'password' && $key ne 'email') {
		$c->detach('/default');
	}

	if ($c->req->method eq 'POST') {
		$c->forward('do_credentials');
	}

	push @{ $c->stash->{title} }, qw/User Credentials/;
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

	push @{ $c->stash->{title} }, 'Resend verification email';
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

	push @{ $c->stash->{title} }, 'Recover lost password';
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

		push @{ $c->stash->{title} }, 'Password Recovery';
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
		relocation   => 'Email Change Requested',
		recovery     => 'Password Recovery Requested',
		verification => 'New User - Verification Required',
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
		$c->detach('/error', [ $c->string('emailLimited') ]);
	}

	$c->log->info("Sending $type email to $mailto");

	$c->stash->{token} = $c->stash->{user}->new_token($type, $mailto);

	$c->stash->{email} = {
		to       => $mailto,
		subject  => $subject->{$type},
		template => $template->{$type},
	};

	$c->forward('View::Email');

	$c->stash->{mailsent} = 1;
	$cache->set($mailto, 1);
}

=head1 AUTHOR

Cameron Thornton E<lt>cthor@cpan.orgE<gt>

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
