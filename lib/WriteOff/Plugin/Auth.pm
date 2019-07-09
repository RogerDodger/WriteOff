package WriteOff::Plugin::Auth;

use Class::Null;
use WriteOff::Util;

sub authenticate {
   my ($c, $username, $password) = @_;

   my $user = $c->model('DB::User')->find({ name_canonical => lc $username });

   if ($user && $user->check_password($password)) {
      $c->session->{__user_id} = $user->id;
      return 1;
   }

   0;
}

sub csrf_token {
   my $c = shift;
   my $key = '__csrf_token';

   return $c->session($key) // ($c->session->{$key} = WriteOff::Util::token());
}

sub csrf_assert {
   my $c = shift;

   $c->detach('/default') unless $c->req->method eq 'POST';

   $c->req->param('csrf_token') eq $c->csrf_token
      or $c->detach('/error', [ $c->string('csrfDetected') ]);
}

sub logout {
   my $c = shift;

   delete $c->stash->{__user};
   delete $c->session->{__user_id};
}

sub user {
   my ($c, $user) = @_;

   if ($user) {
      $c->session->{__user_id} = $user->id;
      return $c->stash->{__user} = $user;
   }

   return $c->stash->{__user} if $c->stash->{__user};

   if (my $uid = $c->session('__user_id')) {
      if (my $user = $c->model('DB::User')->find($uid)) {
         return $c->stash->{__user} = $user;
      }
   }

   return Class::Null->new;
}

sub user_id {
   my $c = shift;
   return $c->user->id || -1;
}

sub user_assert {
   my $c = shift;
   $c->detach('/forbidden', [ $c->string('notUser') ]) unless $c->user;
}

sub post_roles {
   my $c = shift;

   return $c->stash->{__post_roles} //= [
      'user',
      ('organiser') x!! $c->user->organises($c->stash->{event}),
      ('admin') x!! $c->user->admin,
   ];
}

1;
