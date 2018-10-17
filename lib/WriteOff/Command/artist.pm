package WriteOff::Command::artist;

use WriteOff::Command;
use Encode;

sub run {
	my ($self, $command, @args) = @_;

	if (defined $command && $command =~ /^(?:rename|color)$/) {
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

	# Should apply multi-submission penalty if relevant
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

sub color {
	my $self = shift;

	for my $artist ($self->db('Artist')->all) {
		$artist->avatar_write_color->update;

		printf "%16s %7s %s\n",
			$artist->avatar_id // 'default.jpg',
			$artist->color // '',
			Encode::encode_utf8 $artist->name;
	}
}

1;
