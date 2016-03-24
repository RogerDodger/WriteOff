package WriteOff::Command::event;

use WriteOff::Command;
use WWW::Fimfiction;
use Try::Tiny;
use IO::Prompt;
use HTML::Entities qw/decode_entities/;

sub run {
	my ($self, $command, @args) = @_;

	if (defined $command && $command =~ /^(?:export|reset|schedule)$/) {
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

sub reset {
	my $self = shift;
	if (@_ < 1) {
		$self->help;
	}

	my $e = $self->db('Event')->find(shift);
	if (!defined $e) {
		say "Invalid event id";
		exit(1);
	}

	$e->reset_schedules;
}

sub schedule {
	my $self = shift;

	my @events = $self->db('Event')->active->all;

	my $current = shift @events;
	my ($prevFiM, $prevGen);
	for my $e (@events) {
		$prevFiM //= $e if $e->genre->name eq 'FiM';
		$prevGen //= $e if $e->genre->name eq 'General';
	}

	my $cRounds = $current->rounds->ordered->search({ mode => 'fic' });
	my $cWriting = $cRounds->search({ action => 'submit' })->first;

	printf do { local $/ = <DATA> },
		$prevGen->id_uri, $prevGen->prompt, $prevGen->format->name, $prevGen->id_uri,
		$prevFiM->id_uri, $prevFiM->prompt, $prevFiM->format->name, $prevFiM->id_uri,
		$current->id_uri, $current->prompt, $current->format->name, $current->wc_min, $current->wc_max, $current->genre->name,
		$cWriting->start->delta_days($cWriting->end)->days * 24,
		(map { $_->start->strftime("%b %d") } $cWriting, $cRounds->search({ action => "vote" })),
		$current->id_uri;
}

1;

__DATA__
[center][b]Previous General Fiction Round: "[url=http://writeoff.me/event/%s]%s[/url]"[/b] (%s)[/center]
[center][url=http://writeoff.me/event/%s/fic/results]Results[/url][/center]

[center][b]Previous MLP Fanfic Round: "[url=http://writeoff.me/event/%s]%s[/url]"[/b] (%s)[/center]
[center][url=http://writeoff.me/event/%s/fic/results]Results[/url][/center]

[center][b][size=1.5em]Current Round: "[url=http://writeoff.me/event/%s]%s[/url]"[/size][/b][/center]
[center]%s competition (%d–%d words), %s Fiction, %d-hour writing period[/center]
[center]Writing period: Starts %s[/center]
[center]Preliminary Judging: Starts %s[/center]
[center]Finalist Judging: Starts %s[/center]
[center][i]([u]Dates are approximate![/u] See [url=http://writeoff.me/event/%s/fic/submit]the fic submission page[/url] for a countdown timer.)[/i][/center]
