package WriteOff::Plugin::Auth;

use Class::Null;

sub authenticate {
	my ($c, $username, $password) = @_;

	my $user = $c->model('DB::User')->find({ name_canonical => lc $username });

	if ($user && $user->check_password($password)) {
		$c->session->{__user_id} = $user->id;
		return 1;
	}

	0;
}

sub user {
	my ($c, $user) = @_;

	if ($user) {
		$c->session->{__user_id} = $user->id;
		return $c->stash->{__user} = $user;
	}

	return $c->stash->{__user} if exists $c->stash->{__user};

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

sub logout {
	my $c = shift;

	delete $c->stash->{__user};
	delete $c->session->{__user_id};
}

1;
