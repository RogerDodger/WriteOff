package WriteOff::Controller::Schedule;
use Moose;
use namespace::autoclean;
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

sub add :Local {
	my ($self, $c) = @_;

	$c->forward('/assert_admin');
	$c->stash->{sched} = $c->model('DB::Schedule')->new_result({});
	$c->forward('form');
	$c->forward('do_add') if $c->req->method eq 'POST';
}

sub do_add :Private {
	my ($self, $c) = @_;

	$c->forward('do_form');
	$c->stash->{sched}->insert;
	$c->stash->{sched}->create_related('rounds', $_) for @{ $c->stash->{rounds } };

	$c->flash->{status_msg} = $c->string('scheduleUpdated');
	$c->res->redirect($c->uri_for_action('/schedule/index'));
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
	$c->stash->{sched}->update;
	$c->stash->{sched}->rounds->delete;
	$c->stash->{sched}->create_related('rounds', $_) for @{ $c->stash->{rounds } };

	$c->flash->{status_msg} = $c->string('scheduleUpdated');
	$c->res->redirect($c->uri_for_action('/schedule/index'));
}

sub form :Private {
	my ($self, $c) = @_;

	$c->stash->{rorder} = $c->stash->{sched}->rorder;
	$c->stash->{minDate} = WriteOff::DateTime->now->add(days => 2);
	$c->stash->{formats} = $c->model('DB::Format');
	$c->stash->{genres} = $c->model('DB::Genre');
	$c->stash->{modes} = \@WriteOff::Mode::ALL;
}

sub do_form :Private {
	my ($self, $c) = @_;

	$c->forward('/check_csrf_token');

	my $next = WriteOff::DateTime->parse($c->paramo('date'), $c->paramo('time'));
	my $format = $c->stash->{formats}->find_maybe($c->paramo('format'));
	my $genre = $c->stash->{genres}->find_maybe($c->paramo('genre'));
	my $period = $c->parami('period');

	if (grep !defined, $next, $format, $genre, $period) {
		$c->yuck($c->string('badInput'));
	}

	if ($next <= $c->stash->{minDate}) {
		$c->yuck($c->string('nextEventTooSoon'));
	}

	if ($period > $c->config->{biz}{prd}{max}) {
		$c->yuck($c->string('badInput'))
	}

	$c->stash->{sched}->set_columns({
		format_id => $format->id,
		genre_id => $genre->id,
		period => $period,
	});

	$c->stash->{sched}->next($next);

	$c->forward('/round/do_form');
}

__PACKAGE__->meta->make_immutable;

1;
