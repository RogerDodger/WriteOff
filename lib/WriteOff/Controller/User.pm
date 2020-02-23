package WriteOff::Controller::User;
use Moose;
use namespace::autoclean;
use feature ':5.10';
use LWP::UserAgent;
use JSON ();
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
      $c->flash->{status_msg} = 'Artists updated';
      $c->res->redirect($c->uri_for_action($c->action));
   }
}

sub login :Local :Args(0) {
   my ( $self, $c ) = @_;
   $c->yuk('areUser') if $c->user;

   $c->title_push_s('login');
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

sub login_fimfiction :Path('login/fimfiction') :Args(0) {
   my ( $self, $c ) = @_;
   $c->yuk('areUser') if $c->user;
   $c->forward('goto_fimfiction');
}

sub link_fimfiction :Path('link/fimfiction') :Args(0) {
   my ($self, $c) = @_;
   $c->user_assert;
   $c->forward('goto_fimfiction');
}

sub goto_fimfiction :Private {
   my ($self, $c) = @_;
   $c->detach('/default') unless $c->config->{fimfiction_client_id};

   my $token = WriteOff::Util::token();
   $c->config->{tokenCache}->set($c->sessionid, $token);

   my $endpoint = $c->uri_for('/fimfiction');
   $endpoint->scheme('https');

   my $uri = URI->new("https://www.fimfiction.net/authorize-app");
   $uri->query_form(
      client_id => $c->config->{fimfiction_client_id},
      response_type => "code",
      scope => "read_user",
      state => $token,
      redirect_uri => $endpoint,
   );

   $c->res->redirect($uri, 303);
}

sub auth_fimfiction :Path('/fimfiction') :Args(0) {
   my ( $self, $c ) = @_;
   $c->detach('/default') unless $c->config->{fimfiction_client_id};

   my $state = $c->config->{tokenCache}->get($c->sessionid);
   $c->yuk('badSession') if !$state || $state ne $c->req->param('state');

   my $code = $c->req->param('code');

   my $ua = LWP::UserAgent->new(
      timeout => 5,
      # Cloudflare doesn't like the default User-Agent header
      agent => "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"
             . "AppleWebKit/537.36 (KHTML, like Gecko)"
             . "Chrome/71.1.2222.33 Safari/537.36"
      );

   # $ua->add_handler(
   #    "request_send",
   #    sub { shift->dump( maxlength => 0 ); return }
   # );

   # $ua->add_handler(
   #    "response_done",
   #    sub { shift->dump( maxlength => 0 ); return }
   # );

   my $endpoint = $c->uri_for('/fimfiction');
   $endpoint->scheme('https');

   my $res = $ua->post('https://www.fimfiction.net/api/v2/token', {
      client_id => $c->config->{fimfiction_client_id},
      client_secret => $c->config->{fimfiction_client_secret},
      grant_type => 'authorization_code',
      redirect_uri => $endpoint,
      code => $code,
      });

   if (!$res->is_success) {
      $c->log->debug('Failed to get token from Fimfiction: ' . $res->status_line);
      $c->log->debug($res->decoded_content);
      $c->yuk('badSession');
   }
   else {
      $c->log->debug('Got token From Fimfiction: ');
      $c->log->debug($res->decoded_content);
   }

   my $token = JSON::decode_json( $res->decoded_content );
   my $rs = $c->model('DB::User');

   $c->yuk('badSession') unless exists $token->{user}{id} && exists $token->{user}{name};

   my $existing_user = $rs->find({ fimfic_id => $token->{user}{id} });

   if ($c->user) {
      # Link to logged in user
      if (defined $c->user->fimfic_id) {
         $c->flsh_err('youAlreadyHaveLinkedFimficAccount');
      }
      elsif ($existing_user) {
         $c->flsh_err('fimficAccountIsAlreadyLinked');
      }
      else {
         $c->user->update({
            fimfic_id => $token->{user}{id},
            fimfic_name => $token->{user}{name},
            });

         $c->log->info('Fimfic account linked: %d:%s to %d',
            $c->user->fimfic_id, $c->user->fimfic_name, $c->user->id);

         $c->flsh_msg('fimficAccountLinked');
      }

      return $c->res->redirect($c->uri_for_action('/user/accounts'));
   }
   elsif ($existing_user) {
      # Login to existing user
      $c->user($existing_user);
   }
   elsif ( $rs->find({ email_canonical => CORE::fc $token->{user}{email} }) ) {
      $c->flsh_err('fimficEmailExists');
   }
   else {
      # Create new user
      my $user = $rs->create({
         fimfic_id => $token->{user}{id},
         fimfic_name => $token->{user}{name},
         verified => 1,
         email => $token->{user}{email},
         email_canonical => CORE::fc $token->{user}{email},
         });

      $user->update({
         active_artist =>
            $user->create_related('artists', {
               name => $user->fimfic_name,
               name_canonical => CORE::fc $user->fimfic_name,
            })
      });

      $c->user($user);

      $c->log->info( sprintf 'User created from Fimfic: %s (%s)',
         $user->fimfic_name,
         $user->email,
      );
   }

   $c->res->redirect('/');
}

sub logout :Local :Args(0) {
   my ( $self, $c ) = @_;
   $c->logout;
   $c->res->redirect( $c->req->referer || $c->uri_for('/') );
}

sub register :Local :Args(0) {
   my ( $self, $c ) = @_;

   return $c->res->redirect('/') if $c->user;

   push @{ $c->stash->{title} }, 'Register';
   $c->stash->{template} = 'user/register.tt';

   $c->forward('do_register') if $c->req->method eq 'POST';
}

sub do_register :Private {
   my ( $self, $c ) = @_;
   $c->csrf_assert;
   $c->captcha_check;

   $c->form(
      username => [
         'NOT_BLANK',
         [ 'LENGTH', 2, $c->config->{len}{max}{user} ],
         [ 'REGEX', $c->config->{biz}{user}{regex} ],
         [ 'DBIC_UNIQUE', $c->model('DB::User'), 'name' ],
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
      captcha_ok => [ [ 'EQUAL_TO', 1 ] ],
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

      $c->log->info('User created: %s (%s)', $c->stash->{user}->name, $c->stash->{user}->email);

      $c->stash->{mailtype} = { noun => 'verification', verb => 'verify' };
      $c->forward('send_email');
      $c->stash->{status_msg} = 'Registration successful!';
   }
}

sub upgrade :Local :Args(0) {
   my ($self, $c) = @_;
   $c->user_assert;
   $c->detach('/forbidden') if $c->user->password;

   if ($c->req->method eq 'POST') {
      $c->csrf_assert;

      $c->form(
         username => [
            'NOT_BLANK',
            [ 'LENGTH', 2, $c->config->{len}{max}{user} ],
            [ 'REGEX', $c->config->{biz}{user}{regex} ],
            [ 'DBIC_UNIQUE', $c->model('DB::User'), 'name' ],
         ],
         password => [
            'NOT_BLANK',
            [ 'LENGTH', $c->config->{len}{min}{pass}, $c->config->{len}{max}{pass} ]
         ],
         { pass_confirm => [qw/password password2/] } => [ 'DUPLICATION' ],
      );

      if (!$c->form->has_error) {
         $c->user->update({
            password => $c->form->valid('password'),
            name => $c->form->valid('username'),
            name_canonical => CORE::fc $c->form->valid('username'),
         });

         $c->log->info("User upgraded: %d %s", $c->user->id, $c->user->name);

         $c->flash->{status_msg} = $c->string('loginCreated');
         $c->res->redirect($c->uri_for_action( $self->action_for('settings') ));
      }
   }
}

sub settings :Local :Args(0) {
   my ( $self, $c ) = @_;

   $c->detach('/forbidden', [ $c->string('notUser') ]) unless $c->user;

   $c->stash->{modes} = [ @WriteOff::Mode::ALL ];
   $c->stash->{triggers} = [ @WriteOff::EmailTrigger::ALL ];
   $c->stash->{formats} = [ @WriteOff::Format::ALL ];

   $c->forward('do_settings') if $c->req->method eq 'POST';

   $c->stash->{fillform} = {
      font => $c->user->font,
      autosub => $c->user->autosub ? 'on' : '',
      dark => $c->session('dark') ? 'on' : '',
      map {
         my $k = $_;
         my $m = "sub_${_}s";
         my $i = "${_}_id";
         map {
            $k . $_->$i, 'on'
         } $c->user->$m->all;
      } qw/mode trigger format/,
   };
}

sub do_settings :Private {
   my ( $self, $c ) = @_;

   $c->forward('/check_csrf_token');

   $c->user->update({
      font => ($c->req->param('font') // '') =~ /^(serif|sans-serif)$/ ? $1 : 'serif',
      autosub => $c->req->param('autosub') ? 1 : 0,
   });

   $c->session('dark', $c->req->param('dark') ? 1 : 0);

   for my $k (qw/mode trigger format/) {
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
         @{ $c->stash->{"${k}s"} },
      ]);
   }

   $c->flash->{status_msg} = 'Preferences changed successfully';

   $c->res->redirect($c->req->referer || $c->uri_for($c->action));
}

sub password :Local :Args(0) {
   my ($self, $c) = @_;
   $c->password_assert;

   if ($c->req->method eq 'POST') {
      $c->csrf_assert;

      if ( !$c->user->check_password(scalar $c->req->param('password')) ) {
         $c->flash->{error_msg} = $c->string('currentPasswordIsInvalid');
      }
      else {
         my $new1 = $c->req->param('newpassword')  // '';
         my $new2 = $c->req->param('confirmpassword') // '';

         if ($new1 eq $new2) {
            $c->user->update({ password => $new1 });
            $c->flash->{status_msg} = $c->string('passwordChanged');
         }
         else {
            $c->flash->{error_msg} = $c->string('passwordsDoNotMatch');
         }
      }

      $c->res->redirect($c->req->referer || $c->uri_for($c->action));
   }
}

sub email :Local :Args(0) {
   my ($self, $c) = @_;
   $c->password_assert;

   if ($c->req->method eq 'POST') {
      $c->csrf_assert;

      if ( !$c->user->check_password(scalar $c->req->param('password')) ) {
         $c->flash->{error_msg} = $c->string('currentPasswordIsInvalid');
      }
      else {
         my $mailto = $c->stash->{mailto} = CORE::fc $c->req->param('email');

         if (!defined $c->model('DB::User')->find({ email_canonical => $mailto })) {
            $c->stash->{mailtype}{noun} = 'relocation';
            $c->forward('send_email');
            $c->flash->{status_msg} = $c->string('verificationEmailSentTo', $mailto);
         }
         else {
            $c->flash->{error_msg} = $c->string('userWithThatEmailExists');
         }
      }

      $c->res->redirect($c->req->referer || $c->uri_for($c->action));
   }
}

sub accounts :Local :Args(0) {
   my ($self, $c) = @_;
   $c->password_assert;
}

sub unlink_fimfiction :Path('unlink/fimfiction') :Args(0) {
   my ($self, $c) = @_;
   $c->password_assert;

   if ($c->req->method eq 'POST') {
      $c->csrf_assert;

      if ($c->user->fimfic_id) {
         $c->log->info('User %d unlinked fimfic account: %d:%s',
            $c->user->id, $c->user->fimfic_id, $c->user->fimfic_name);

         $c->user->update({
            fimfic_name => undef,
            fimfic_id => undef,
            });

         $c->flsh_msg('fimficAccountUnlinked');
      }
   }

   $c->res->redirect($c->uri_for_action('/user/accounts'));
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

sub groups :Local {
   my ($self, $c) = @_;

   $c->user_assert;

   $c->stash->{subs} = $c->user->groups;
   $c->stash->{members} = $c->user->artists->related_resultset('artist_genre');
}

=head1 AUTHOR

Cameron Thornton E<lt>cthor@cpan.orgE<gt>

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
