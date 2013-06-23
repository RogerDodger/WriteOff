package WriteOff::Command::artist;

use WriteOff::Command;

sub run {
	my ($self, $command, @args) = @_;

	if (defined $command && $command =~ /^(?:rename)$/) {
		$self->$command(@args);
	}
	else {
		$self->help;
	}	
}

sub rename {
	my $self = shift;
	if (@_ < 2) {
		$self->help;
	}

	my $oldname = shift;
	if ($oldname eq 'Anonymous') {
		say "Cannot rename `Anonymous`";
		exit(1);
	}

	my $old = $self->db('Artist')->find({ name => $oldname });
	if (!defined $old) {
		say "Artist `$oldname` does not exist";
		exit(1);
	}

	my $newname = shift;
	my $new = $self->db('Artist')->find({ name => $newname });

	my @scores = $old->scores;
	
	if (!defined $new) {
		printf "Renaming `%s` to `%s`...\n", $old->name, $newname;
		$old->update({ name => $newname });
	}
	else {
		$newname = $new->name;
		printf "Merging `%s` into `%s`...\n", $old->name, $newname;
		$old->scores->update({ artist_id => $new->id });
		$old->artist_awards->update({ artist_id => $new->id });
		$old->delete;
		$new->recalculate_score;
	}

	for my $score (@scores) {
		eval {
			$score->story->update({ author => $newname });
		};
		eval {
			$score->image->update({ artist => $newname });
		};
	}
}

1;
