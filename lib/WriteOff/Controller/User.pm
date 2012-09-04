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
	
	$c->detach('/forbidden', ['You are not logged in.']) unless $c->user_exists;
	
	if( $c->check_user_roles($c->user, qw/admin/) ) {
		$c->stash->{images}  = $c->model('DB::Image');
		$c->stash->{storys}  = $c->model('DB::Story');
		$c->stash->{prompts} = $c->model('DB::Prompt');
	}
	else {
		$c->stash->{images}  = $c->model('DB::Image')->search ({ user_id => $c->user->id });
		$c->stash->{storys}  = $c->model('DB::Story')->search ({ user_id => $c->user->id });
		$c->stash->{prompts} = $c->model('DB::Prompt')->search({ user_id => $c->user->id });
	}
	
	$c->stash->{template} = 'user/me.tt';
}

sub login :Local :Args(0) {
    my ( $self, $c ) = @_;
	
	my $success = 
		$c->req->params->{username} =~ $c->config->{biz}->{user}->{regex} &&
		$c->authenticate({ 
			password => $c->req->params->{password},
			dbix_class => { searchargs => [{
				#Case-insensitive login
				username => { like => $c->req->params->{username} } 
			}]},
		});

	if($success) {
		$c->user->verified ||
		$c->flash({error_msg => 'Your account is not verified'}) && $c->logout;
	}
	else {
		$c->flash({error_msg => 'Bad username or password'});
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
	
	$c->stash->{timezones} = [qw/UTC/, grep {/\//} DateTime::TimeZone->all_names];
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
	
	$c->detach('/') unless DateTime::TimeZone->is_valid_name($params->{timezone});
	
	$c->form(
		username => ['NOT_BLANK', ['LENGTH', 1, $c->config->{len}->{max}->{user}], 
			['REGEX', $c->config->{biz}->{user}->{regex} ] ],
		unique_user => [ [qw/EQUAL_TO 0/] ],
		password => ['NOT_BLANK', ['LENGTH', $c->config->{len}->{min}->{pass}, 
			$c->config->{len}->{max}->{pass}] ],
		{ pass_confirm => [qw/password password2/] } => ['DUPLICATION'],
		email => [qw/NOT_BLANK EMAIL_MX/],
		unique_email => [ [qw/EQUAL_TO 0/] ],
		captcha => [ [qw/EQUAL_TO 1/] ],
	);
	
	if(!$c->form->has_error) {
		$c->stash->{user} = $rs->create({
			username => $params->{username},
			password => $params->{password},
			email    => $params->{email},
			mailme   => !!$params->{mailme},
			timezone => $params->{timezone},
			ip       => $c->req->address,
		});
		
		$c->stash->{token} = $c->stash->{user}->new_token;
		
		$c->model("DB::UserRole")->create({
			user_id => $c->stash->{user}->id,
			role_id => 2,
		});
		
		$c->stash->{email} = {
			to           => $c->stash->{user}->email,
			from         => 'noreply@' . $c->config->{domain},
			subject      => $c->config->{name} . ' - Confirmation Email',
			template     => 'email/registration.tt',
			content_type => 'text/html',
		};
		
		$c->forward($c->view('Email::Template'));
		$c->stash->{template} = 'user/register_successful.tt';
	}
}

sub settings :Local :Args(0) {
	my ( $self, $c ) = @_;
	
	$c->detach('/forbidden', ['You are not logged in.']) unless $c->user; 
	$c->detach('/forbidden', ['Your account is not verified.']) unless $c->user->verified; 
	
	$c->stash->{timezones} = [qw/UTC/, grep {/\//} DateTime::TimeZone->all_names];
	if($c->req->method eq 'POST') {
		$c->stash->{error_msg}  = $c->forward('do_settings') or
		$c->stash->{status_msg} = 'Settings changed successfully';
	}
	
	$c->stash->{template} = 'user/settings.tt';
}

sub do_settings :Private {
	my ( $self, $c ) = @_;
	
	if($c->req->params->{type} eq 'password') {
		my($old, $new, $new2) = @{$c->req->params}{qw/old_password password password2/};
		
		return "One or more fields empty" if grep {$_ eq ''} ($old, $new, $new2);
		
		$c->authenticate({ 
			username => $c->user->username,
			password => $old,
		}) || return 'Incorrect password given';
		
		return 'Passwords do not match' unless $new eq $new2;
		return 'Password too short' if length($new) < $c->config->{len}->{min}->{pass};
		
		$c->user->update({password => $new});
	}
	elsif($c->req->params->{type} eq 'timezone') {
		return 'Error: Invalid timezone' unless 
			DateTime::TimeZone->is_valid_name($c->req->params->{timezone});
			
		$c->user->update({ timezone => $c->req->params->{timezone} });
		$c->set_authenticated($c->user);
	} else {
		return 'Error: Unknown';
	}
	0;
}

sub verify :Local :Args(2) {
	my ( $self, $c, $id, $token ) = @_;
	
	my $rs = $c->model('DB::User');
	my $user = $rs->find($id);
	
	if($user && $user->token eq $token) {
		if($c->req->params->{delete}) { 
			$user->delete;
			$c->stash->{template} = 'user/verify_delete.tt';
		}
		else { 
			$user->update({ verified => 1 });
			$user = $c->find_user({ id => $id });
			$c->set_authenticated($user);
			$user->new_token;
			$c->stash->{template} = 'user/verify.tt';
		}
	} else {
		$c->res->redirect( $c->uri_for('/') );
	}
}

=head1 AUTHOR

Cameron Thornton <cthor@cpan.org>

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
