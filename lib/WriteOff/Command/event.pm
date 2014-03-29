package WriteOff::Command::event;

use WriteOff::Command;
use WWW::Fimfiction;
use Try::Tiny;
use IO::Prompt;
use HTML::Entities qw/decode_entities/;

sub run {
	my ($self, $command, @args) = @_;

	if (defined $command && $command =~ /^(?:export)$/) {
		$self->$command(@args);
	}
	else {
		$self->help;
	}
}

sub export {
	my $self = shift;
	if (@_ < 3) {
		$self->help;
	}

	my ($eid, $sid, $username) = @_;
	my $password = prompt('Password: ', -e => '*');
	my $ua = WWW::Fimfiction->new;

	my $event = $self->db('Event')->find($eid);
	if (!defined $event) {
		say "Invalid event id";
		exit(1);
	}

	try {
		$ua->login($username, $password);

		my $story = $ua->get_story($sid);

		if (!defined $story) {
			die "Invalid story id";
		}

		if ($story->{author}{name} ne $username) {
			die "Username does not match given story author's name";
		}

		if (decode_entities($story->{title}) ne $event->prompt) {
			die "Story title does not match event prompt";
		}

		# Delete old chapters to make sure we don't end up with an inordinate
		# number of dupes.
		if ($story->{chapter_count} != 0) {
			my $ans = prompt(
			      "$story->{chapter_count} existing chapters will be overwritten. "
			    . "Continue? [y/n] "
			);
			if ($ans !~ /^(?:y|yes)$/i) {
				say "Aborting...";
				exit(2);
			}
			for my $chapter (@{ $story->{chapters} }) {
				print 'Deleting ' . $chapter->{title} . ' ... ';
				$ua->delete_chapter($chapter->{id});
				say 'done';
			}
			say '';
		}

		my $upload_story = sub {
			my ($title, $contents) = @_;
			print "Uploading $title ... ";
			my $chapter = $ua->add_chapter($sid, $title, $contents);
			$ua->publish_chapter($chapter);
			say 'done';
		};

		my $storys = $event->storys->seed_order;

		for my $story ($storys->candidates->all) {
			$upload_story->($story->title, $story->contents);
		}

		$upload_story->('VOTING');

		for my $story ($storys->noncandidates->all) {
			$upload_story->($story->title, $story->contents);
		}
	} catch {
		chomp and s/ at .+? line \d+$// and say;
		exit(1);
	};
}

1;
