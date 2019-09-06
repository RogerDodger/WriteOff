package WriteOff::Controller::Schedule;
use Moose;
use namespace::autoclean;
use Try::Tiny;
use WriteOff::Format;
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

   $c->stash->{schedules} = $c->model('DB::Schedule')->promoted->index;
}

sub add :Chained('/group/fetch') :PathPart('schedule/add') :Args(0) {
   my ($self, $c) = @_;

   $c->detach('/default') if !$c->stash->{group}->established;
   $c->no('notGroupAdmin') if !$c->user->admins($c->stash->{group});

   $c->stash->{sched} = $c->model('DB::Schedule')->new_result({});
   $c->forward('form');
   $c->forward('do_add') if $c->req->method eq 'POST';
}

sub do_add :Private {
   my ($self, $c) = @_;

   $c->forward('do_form');
   $c->stash->{sched}->genre_id($c->stash->{group}->id);
   $c->stash->{sched}->insert;
   $c->stash->{sched}->create_related('rounds', $_) for @{ $c->stash->{rounds} };

   $c->flash->{status_msg} = $c->string('scheduleUpdated');
   $c->res->redirect($c->uri_for_action('/group/schedule', [ $c->stash->{group}->id_uri ]));
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
   $c->stash->{formats} = \@Writeoff::Format::ALL;
   $c->stash->{genres} = $c->model('DB::Genre');
   $c->stash->{modes} = \@WriteOff::Mode::ALL;
}

sub do_form :Private {
   my ($self, $c) = @_;
   $c->csrf_assert;

   my $next = WriteOff::DateTime->parse($c->paramo('date'), $c->paramo('time'));
   my $period = $c->parami('period');
   my $wc_min = $c->parami('wc_min');
   my $wc_max = $c->parami('wc_max');
   ($wc_min, $wc_max) = ($wc_max, $wc_min) if $wc_min > $wc_max;

   $c->yuk('badInput')
      if (grep !defined, $next, $period)
      || $wc_max <= 0 || $period > $c->config->{biz}{prd}{max};

   $c->yuk('nextEventTooSoon')
      if $next <= $c->stash->{minDate};

   $c->stash->{sched}->set_columns({
      wc_min => $wc_min,
      wc_max => $wc_max,
      period => $period,
   });

   $c->stash->{sched}->next($next);

   $c->forward('/round/do_form');
}

__PACKAGE__->meta->make_immutable;

1;
