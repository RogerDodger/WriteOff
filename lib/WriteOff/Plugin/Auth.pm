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

	return $c->session->{__csrf_token} //= WriteOff::Util::token();
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

	if (exists $c->session->{__user_id}) {
		if (my $user = $c->model('DB::User')->find($c->session->{__user_id})) {
			return $c->stash->{__user} = $user;
		}
	}

	return Class::Null->new;
}

sub user_id {
	my $self = shift;

	return $self->user->id || -1;
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
