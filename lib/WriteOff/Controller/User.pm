package WriteOff::Controller::User;
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller'; }

=head1 NAME

WriteOff::Controller::User - Catalyst Controller

=head1 DESCRIPTION

Controller for user management - login/logout, registration, settings, etc.

=cut

sub me :Local :Args(0) {
	my ( $self, $c ) = @_;
	
	$c->detach('/forbidden', ['You are not logged in.']) unless $c->user;
	
	if( $c->check_user_roles('admin') ) {
		$c->stash->{images}  = $c->model('DB::Image');
		$c->stash->{storys}  = $c->model('DB::Story');
		$c->stash->{prompts} = $c->model('DB::Prompt');
	}
	else {
		$c->stash->{images}  = $c->user->obj->images;
		$c->stash->{storys}  = $c->user->obj->storys;
		$c->stash->{prompts} = $c->user->obj->prompts;
	}
	
	$c->stash->{template} = 'user/me.tt';
}

sub login :Local :Args(0) {
    my ( $self, $c ) = @_;
	
	$c->res->redirect( $c->uri_for('/') ) and return 0 if $c->user;
	
	$c->detach('login_attempts_exceeded') if $c->model('DB::LoginAttempt')
		->search({ ip => $c->req->address })
		->created_after( 
			DateTime->now->subtract( minutes => $c->config->{login}{timer} ) 
		)
		->count >= $c->config->{login}{limit};
	
	my $success = 
		($c->req->params->{Username} || '') =~ $c->config->{biz}{user}{regex} &&
		$c->authenticate({ 
			password => $c->req->params->{Password} || '',
			dbix_class => { searchargs => [{
				#Case-insensitive login
				username => { like => $c->req->params->{Username} } 
			}]},
		});

	if($success) {
		$c->user->verified ||
		$c->flash({error_msg => 'Your account is not verified'}) && $c->logout;
	}
	else {
		$c->model('DB::LoginAttempt')->create({ ip => $c->req->address });
		$c->flash({error_msg => 'Bad username or password'});
	}
	
	$c->res->redirect( $c->req->referer || $c->uri_for('/') );
}

sub login_attempts_exceeded :Private {
	my ( $self, $c ) = @_;
	
	$c->stash->{template} = 'user/login_attempts_exceeded.tt';
}

sub logout :Local :Args(0) {
    my ( $self, $c ) = @_;
	$c->logout;
	$c->res->redirect( $c->uri_for('/') );
}

sub register :Local :Args(0) {
	my ( $self, $c ) = @_;
	
	$c->res->redirect( $c->uri_for('/') ) if $c->user;
	
	$c->stash->{timezones} = [ $self->timezones ];
	$c->stash->{template} = 'user/register.tt';
	
	$c->forward('/captcha_get');
	$c->forward('do_register') if $c->req->method eq 'POST';
}

sub do_register :Private {
	my ( $self, $c ) = @_;
	
	my $params = $c->req->params;
	my $rs = $c->model('DB::User');
	$params->{captcha}      = $c->forward('/captcha_check');
	$params->{unique_user}  = $rs->user_exists ( $params->{username} );
	$params->{unique_email} = $rs->email_exists( $params->{email} );
	
	$c->form(
		username => [ 'NOT_BLANK', [ 'LENGTH', 1, $c->config->{len}{max}{user} ], 
			[ 'REGEX', $c->config->{biz}{user}{regex} ] ],
		unique_user => [ ['EQUAL_TO', 0] ],
		password => ['NOT_BLANK', [ 'LENGTH', $c->config->{len}{min}{pass}, 
			$c->config->{len}{max}{pass} ] ],
		{ pass_confirm => [qw/password password2/] } => ['DUPLICATION'],
		email        => [ 'NOT_BLANK', 'EMAIL_MX' ],
		unique_email => [ [ 'EQUAL_TO', 0 ] ],
		timezone     => [ 'NOT_BLANK', [ 'IN_ARRAY', $self->timezones ] ],
		captcha      => [ [ 'EQUAL_TO', 1 ] ],
	);
	
	if(!$c->form->has_error) {
		$c->stash->{user} = $rs->create({
			username => $c->form->valid('username'),
			password => $c->form->valid('password'),
			email    => $c->form->valid('email'),
			timezone => $c->form->valid('timezone'),
			ip       => $c->req->address,
			mailme   => $c->req->params->{mailme} ? 1 : 0,
		});
		$c->stash->{user}->new_token;
		
		$c->model("DB::UserRole")->create({
			user_id => $c->stash->{user}->id,
			role_id => 2,
		});
		
		$c->stash->{email} = {
			to           => $c->stash->{user}->email,
			from         => $c->config->{AdminName} . ' ' . '<' . 'noreply@' . 
				$c->config->{domain} . '>',
			subject      => $c->config->{name} . ' - Confirmation Email',
			template     => 'email/registration.tt',
			content_type => 'text/html',
		};
		
		$c->forward( $c->view('Email::Template') );
		$c->stash->{template} = 'user/register_successful.tt';
	}
}

sub settings :Local :Args(0) {
	my ( $self, $c ) = @_;
	
	$c->detach('/forbidden', ['You are not logged in.']) unless $c->user; 
	
	$c->stash->{timezones} = [ $self->timezones ];
	
	$c->forward('do_settings') if $c->req->method eq 'POST';
	
	$c->stash->{template} = 'user/settings.tt';
}

sub do_settings :Private {
	my ( $self, $c ) = @_;
	
	return 0 unless $c->req->params->{sessionid} eq $c->sessionid;
	
	if( $c->req->params->{submit} eq 'Change password' ) {
		
		$c->req->params->{old_password} = $c->req->params->{old} && 0 + $c->user
			->obj->discard_changes->check_password( $c->req->params->{old} );
		
		$c->form(
			password => [ 'NOT_BLANK', [ 'LENGTH', $c->config->{len}{min}{pass}, 
				$c->config->{len}{max}{pass} ] ],
			{ pass_confirm => [qw/password password2/] } => ['DUPLICATION'],
			old_password => [ 'NOT_BLANK', [ 'EQUAL_TO', 1 ] ],
		);
		
		return 0 if $c->form->has_error;
		
		$c->user->update({ password => $c->form->valid('password')});
		$c->stash->{status_msg} = 'Password changed successfully';
	}
	
	elsif( $c->req->params->{submit} eq 'Change timezone' ) {
		$c->form(
			timezone => [ 'NOT_BLANK', [ 'IN_ARRAY', $self->timezones ] ],
		);
		return 0 if $c->form->has_error;
		
		$c->user->update({ timezone => $c->form->valid('timezone') });
		$c->set_authenticated($c->user);
		$c->stash->{status_msg} = 'Timezone changed successfully';
	} 
	
	elsif( $c->req->params->{submit} eq 'Change notifications' ) {
		$c->user->update({ mailme => $c->req->params->{mailme} ? 1 : 0 });
		$c->set_authenticated($c->user);
		$c->stash->{status_msg} = 'Notifications changed successfully';
	}
	
	0;
}

sub verify :Local :Args(2) {
	my ( $self, $c, $id, $token ) = @_;
	
	my $user = $c->model('DB::User')->find($id);
	
	if( $user && $user->token eq $token ) {
		if( $c->req->params->{delete} ) { 
			$user->delete;
			$c->stash->{template} = 'user/verify_delete.tt';
		}
		else { 
			$user->update({ verified => 1 });
			$user->new_token;
			$c->set_authenticated( $c->find_user({ id => $id }) );
			$c->stash->{template} = 'user/verify.tt';
		}
	} 
	else {
		$c->res->redirect( $c->uri_for('/') );
	}
}

sub timezones {
	my ( $self, $c ) = @_;
	
	return qw/UTC/, grep {/\//} DateTime::TimeZone->all_names;
}

=head1 AUTHOR

Cameron Thornton E<lt>cthor@cpan.orgE<gt>

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
