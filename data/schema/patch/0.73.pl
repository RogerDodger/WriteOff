use 5.01;
use autodie;
use FindBin '$Bin';
BEGIN {
	chdir "$Bin/../../..";
	push @INC, './lib';
}
use WriteOff::Schema;
use WriteOff::Award qw/:all/;

my $s = WriteOff::Schema->connect("dbi:SQLite:data/WriteOff.db","","", {
	sqlite_unicode => 1,
});

my $events = $s->resultset('Event')->search(
	{ tallied => 1 },
	{ order_by => { -asc => 'created' } },
);

my %grads = ( fic => {}, art => {} );

for my $event ($events->all) {
	my @sets = scalar $event->storys;
	push @sets, scalar $event->images if $event->has('art');

	for my $rs (@sets) {
		my $prev;
		for my $entry ($rs->eligible->rank_order->all) {
			if (!$grads{$entry->mode}{$entry->artist_id}) {
				if (!$prev || $prev->rank == $entry->rank) {
					$prev = $entry;
					$grads{$entry->mode}{$entry->artist_id} = 1;

					if (my $award = $entry->awards->search({ award_id => RIBBON()->id })->first) {
						$award->update({ award_id => MORTARBOARD()->id });
					}
					else {
						$entry->create_related('awards', { award_id => MORTARBOARD()->id });
					}
				}
			}
		}
	}
}
