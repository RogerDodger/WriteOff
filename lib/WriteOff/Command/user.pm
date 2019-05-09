package WriteOff::Command::user;

use WriteOff::Command;
use IO::Prompt;

can add =>
	sub {
		my ($name, $email, $role) = @_;

		$role =~ /^(user|admin)$/ or abort qq{Invalid role "$role"};

		my $password = prompt('Password: ', -e => '*');
		my $password2 = prompt('Confirm password: ', -e => '*');
		$password eq $password2 or abort "Passwords do not match";

		say "Creating user $name...";

		my $user = db('User')->create({
			name            => $name,
			name_canonical  => CORE::fc $name,
			password        => $password,
			email           => $email,
			email_canonical => CORE::fc $email,
			verified        => 1,
		});

		my $artist = db('Artist')->create({
			user_id => $user->id,
			name => $user->name,
			name_canonical => $user->name_canonical,
			admin => 0+($role eq 'admin'),
			# For some bizarre reason, this isn't being done automatically BUT ONLY
			# HERE. Artist->create has auto timestamps everywhere else, and
			# User->create just above this does too ... ???
			created => DateTime->now,
			updated => DateTime->now,
		});

		$user->update({ active_artist_id => $artist->id });
	},
	which => q{
		Creates a user with name NAME and email EMAIL. Password is input as a
		prompt. If ROLE eq 'admin', the user will have admin privileges.
	},
	with => [
		name => undef,
		email => undef,
		role => 'user',
	],
	fetch => 0;

# sub rename {
# 	my $self = shift;

# 	if (@_ < 2) {
# 		$self->help;
# 	}

# 	my $oldname = shift;
# 	my $sub = $self->db('User')->find({ username => $oldname });
# 	if (!defined $sub) {
# 		say "User `$oldname` does not exist";
# 		exit(1);
# 	}

# 	my $newname = shift;
# 	my $main = $self->db('User')->find({ username => $newname });

# 	if (!defined $main) {
# 		printf "Renaming `%s` to `%s`...\n", $sub->name, $newname;
# 		$sub->update({ username => $newname });
# 	}
# 	else {
# 		printf "Merging `%s` into `%s`...\n", $sub->name, $main->name;

# 		for my $table (qw/Artist Image Story Prompt VoteRecord/) {
# 			$self->db($table)
# 			       ->search({ user_id => $sub->id })
# 			         ->update({ user_id => $main->id });
# 		}

# 		# These can fail if there's a PK conflict (e.g., both users have role
# 		# `admin`, and it tries to update $main to being a `admin` twice).
# 		# Rather than checking if a conflict exists, it's quicker to just try
# 		# it and let the DBMS sort it out.
# 		for my $table (qw/UserEvent UserRole/) {
# 			for my $row ($self->db($table)->search({ user_id => $sub->id })) {
# 				eval {
# 					$row->update({ user_id => $main->id });
# 				}
# 			}
# 		}

# 		$sub->delete;
# 	}
# }

'Merging is complete';
