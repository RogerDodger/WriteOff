use 5.01;
use autodie;
use File::Temp qw/tempfile/;
use FindBin '$Bin';
BEGIN {
	chdir "$Bin/../..";
	push @INC, './lib';
}
use WriteOff::Schema;

my $s = WriteOff::Schema->connect("dbi:SQLite:data/WriteOff.db","","", {
	sqlite_unicode => 1,
});

for my $user ($s->resultset('User')->all) {
	my $storys = $user->storys->search({ event_id => 34 });
	my $records = $user->vote_records->prelim->search({ event_id => 34 });

	while (my $story = $storys->next) {
		$records->next->update({ story_id => $story->id });
	}
}
