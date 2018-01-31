package WriteOff::Controller::Schedule;
use Moose;
use namespace::autoclean;
use DateTime::Format::Pg;
use Try::Tiny;
use WriteOff::Mode;
use WriteOff::Util qw/uniq/;

BEGIN { extends 'Catalyst::Controller' }

__PACKAGE__->config(model => 'Schedule');

sub _fetch :ActionClass('~Fetch') {}

sub fetch :Chained('/') :PathPart('schedule') :CaptureArgs(1) {
	my ($self, $c) = @_;
	$c->forward('_fetch');
	my $sched = $c->stash->{sched} = $c->stash->{schedule};
	push @{ $c->stash->{title} }, $c->string('scheduleAt', $sched->next->strftime('%d %b'));
}

sub index :Path :Args(0) {
	my ($self, $c) = @_;

	$c->stash->{schedules} = $c->model('DB::Schedule')->search({}, { order_by => 'next' });
}

sub form :Private {
	my ($self, $c) = @_;

	$c->stash->{rorder} = $c->stash->{sched}->rorder;
	$c->stash->{minDate} = WriteOff::DateTime->now->add(days => 2)->strftime('%Y-%m-%d');
	$c->stash->{formats} = $c->model('DB::Format');
	$c->stash->{genres} = $c->model('DB::Genre');
	$c->stash->{modes} = \@WriteOff::Mode::ALL;
	$c->stash->{actions} = [ 'submit', 'vote' ];
}

sub do_form :Private {
	my ($self, $c) = @_;

	$c->forward('/check_csrf_token');

	my $next = try {
		DateTime::Format::Pg->parse_datetime(
			$c->paramo('nextDate') . ' ' . $c->paramo('nextTime')
		);
	};

	my $format = $c->stash->{formats}->find_maybe($c->paramo('format'));
	my $genre = $c->stash->{genres}->find_maybe($c->paramo('genre'));
	my $period = $c->parami('period');

	my @modes = $c->req->param('mode');
	my @durs = $c->req->param('duration');

	if (@modes <= @durs) {
		my @rounds;
		for my $i (0..$#modes) {
			my $mode = WriteOff::Mode->find($modes[$i] // '')
				or $c->yuck($c->string('badInput'));
			$durs[$i] =~ /(\d+)/ and $1 > 0 and $1 < 60
				or $c->yuck($c->string('badInput'));

			push @rounds, {
				mode => $mode->name,
				duration => int $1,
			}
		}

		my %names = (
			vote => [
				[ 'final' ],
				[ 'prelim', 'final' ],
				[ 'prelim', 'semifinal', 'final' ],
			],
			submit => {
				art => 'drawing',
				fic => 'writing',
			},
		);

		my @modes = uniq map { $_->{mode} } @rounds;
		my %offset = map { $_ => 0 } @modes;
		if (@modes == 2) {
			my $rorder = $c->paramo('rorder') || 'simul';

			if ($rorder eq 'fic2pic' || $rorder eq 'pic2fic') {
				$rorder =~ s/pic/art/;
				my $fr = substr $rorder, 0, 3;
				my $to = substr $rorder, 4, 3;

				my @fr = grep { $_->{mode} eq $fr } @rounds;
				$offset{$to} = $fr[0]->{duration};
			}
		}

		for my $mode (@modes) {
			my $offset = $offset{$mode};
			my @tl = grep { $_->{mode} eq $mode } @rounds;
			my @s = @tl[0];
			my @v = @tl[1..$#tl];

			if ($#v > 2) {
				$c->yuck($c->string('tooManyRounds'));
			}

			for my $i (0..$#s) {
				$s[$i]->{action} = 'submit';
				$s[$i]->{name} = $names{submit}{$mode};
			}

			for my $i (0..$#v) {
				$v[$i]->{action} = 'vote';
				$v[$i]->{name} = $names{vote}[$#v][$i];
			}

			for my $round (@tl) {
				$round->{offset} = $offset;
				$offset += $round->{duration};
			}
		}

		$c->stash->{schedule}->rounds->delete;
		$c->stash->{schedule}->create_related('rounds', $_) for @rounds;
	}
}

sub edit :Chained('fetch') :PathPart('edit') :Args(0) {
	my ($self, $c) = @_;

	$c->forward('/assert_admin');

	$c->forward('form');

	$c->forward('do_edit') if $c->req->method eq 'POST';
}

sub do_edit :Private {
	my ($self, $c) = @_;

	$c->forward('do_form');

	$c->flash->{status_msg} = $c->string('scheduleUpdated');
	$c->res->redirect($c->uri_for_action('/schedule/index'));
}

__PACKAGE__->meta->make_immutable;

1;
