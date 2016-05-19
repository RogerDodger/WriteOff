package WriteOff::Command::user;

use WriteOff::Command;
use IO::Prompt;

sub run {
	my ($self, $command, @args) = @_;

	if (defined $command && $command =~ /^(?:add|rename)$/) {
		$self->$command(@args);
	}
	else {
		$self->help;
	}
}

sub add {
	my ($self, $name, $email, $role) = @_;

	if (!defined $name || !defined $email) {
		$self->usage;
	}

	my $password = prompt('Password: ', -e => '*');
	my $password2 = prompt('Confirm password: ', -e => '*');
	if ($password ne $password2) {
		say "Passwords do not match";
		exit(1);
	}

	say "Creating user $name...";

	my $user = $self->db('User')->create({
		name            => $name,
		name_canonical  => lc $name,
		password        => $password,
		email           => $email,
		email_canonical => lc $email,
		admin           => defined $role && $role eq 'admin',
	});

	$user->update({ active_artist_id =>
		$user->create_related('artists', { name => $user->name })->id,
	});
}

sub rename {
	my $self = shift;

	die "Not implemented\n";

	if (@_ < 2) {
		$self->help;
	}

	my $oldname = shift;
	my $sub = $self->db('User')->find({ username => $oldname });
	if (!defined $sub) {
		say "User `$oldname` does not exist";
		exit(1);
	}

	my $newname = shift;
	my $main = $self->db('User')->find({ username => $newname });

	if (!defined $main) {
		printf "Renaming `%s` to `%s`...\n", $sub->name, $newname;
		$sub->update({ username => $newname });
	}
	else {
		printf "Merging `%s` into `%s`...\n", $sub->name, $main->name;

		for my $table (qw/Artist Image Story Prompt VoteRecord/) {
			$self->db($table)
			       ->search({ user_id => $sub->id })
			         ->update({ user_id => $main->id });
		}

		# These can fail if there's a PK conflict (e.g., both users have role
		# `admin`, and it tries to update $main to being a `admin` twice).
		# Rather than checking if a conflict exists, it's quicker to just try
		# it and let the DBMS sort it out.
		for my $table (qw/UserEvent UserRole/) {
			for my $row ($self->db($table)->search({ user_id => $sub->id })) {
				eval {
					$row->update({ user_id => $main->id });
				}
			}
		}

		$sub->delete;
	}
}

'Merging is complete';
