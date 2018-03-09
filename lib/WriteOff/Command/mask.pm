use utf8;
package WriteOff::Command::mask;

use WriteOff::Command;
use WriteOff::Util qw/uniq/;
use List::Util qw/max min sum/;
use Statistics::QuickMedian qw/qmedian/;

binmode STDOUT, ':utf8';

sub avg { sum(@_) / @_ }

sub run {
	my ($self, $command, @args) = @_;

	my @masks;
	for my $event ($self->db('Event')->search({ guessing => 1 })) {
		my @entrys = $event->storys->eligible->search({}, { prefetch => 'artist' });
		my @artists = uniq map $_->artist_id, @entrys;

		my %F =  map { $_->id => 0 } @entrys;
		my %Le = map { $_->id => 0 } @entrys;
		my %La = map { $_ => 0 } @artists;

		# for my $theory ($event->theorys) {
		for my $theory ($event->theorys->search({ accuracy => { '!=' => 0 } })) {
			my @guesses = $theory->guesses->search({}, { prefetch => 'entry' });

			my %n = map { $_ => 0 } @artists;
			my %c = map { $_ => 0 } @artists;

			for my $g (@guesses) {
				$g->{correct} = $g->entry->artist_id == $g->artist_id;
				$n{$g->artist_id}++;
				$c{$g->artist_id}+= $g->{correct};
			}

			for my $g (@guesses) {
				my $p = min(1, ($c{$g->artist_id} + 1) / $n{$g->artist_id}) ** 1.25;

				$F{$g->entry_id}   += $p if $g->{correct};
				$Le{$g->entry_id}  += $p;
				$La{$g->artist_id} += $p if !$g->{correct};
			}
		}

		my $R = @entrys / @artists;

		my @candidates = grep { $F{$_->id} < 0.8 && $Le{$_->id} >= 1 && $La{$_->artist_id} >= 1 } @entrys;

		$_->{L} = $La{$_->artist_id} + $Le{$_->id} * $R for @candidates;

		my $outlier = outlier(map $_->{L}, @candidates);

		printf "=== %2d %s ===\n-- %d ~ %.2f\n", $event->id, $event->prompt, $#entrys+1, $outlier;

		my $masks = 0;
		$masks += printf "%4d %-20s  %-12s %5.2f | %5.2f %5.2f %s %5.2f\n",
			$_->id, substr($_->title, 0, 20), substr($_->artist->name, 0, 12),
			$F{$_->id}, $Le{$_->id}, $La{$_->artist_id}, ($_->{L} < $outlier ? "x" : "~"), $_->{L}
				for sort { $b->{L} <=> $a->{L} }
					grep { $_->{L} > $outlier }
					@candidates;

		push @masks, $masks;
	}

	my $avg = avg(@masks);
	printf "* %.2f ± %.2f\n", $avg, sqrt avg(map ($_ - $avg)**2, @masks);
}

sub outlier {
	# my $med = qmedian(\@_);
	# my $mad = qmedian([map abs($_ - $med), @_]);

	# return $med + $mad * 3;

	my $avg = avg(@_);
	my $sdv = sqrt avg(map ($_ - $avg)**2, @_);

	return $avg + $sdv * 1.65; # 1.65 ~= inv_cdf(0.95)
}

1;
