package WriteOff::Controller::Notif;
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller'; }

sub fetch :Chained('/') :PathPart('notif') :CaptureArgs(1) :ActionClass('~Fetch') {}

sub clear :Chained('fetch') :PathPart('clear') Args(0) {
	my ($self, $c) = @_;

	$c->forward('/check_csrf_token');

	if ($c->user->id == $c->stash->{notif}->user_id) {
		$c->stash->{notif}->update({ read => 1 });
	}

	$c->res->redirect($c->req->referer || '/user/notifs');
}

sub clear_all :Path('/user/notifs/clear') {
	my ($self, $c) = @_;

	$c->forward('/check_csrf_token');

	$c->user->notifs->update({ read => 1 });

	$c->res->redirect($c->req->referer || '/user/notifs');
}

sub follow :Chained('fetch') :PathPart('follow') Args(0) {
	my ($self, $c) = @_;

	$c->forward('/check_csrf_token');

	if ($c->user->id == $c->stash->{notif}->user_id) {
		$c->stash->{notif}->update({ read => 1 }) if !$c->stash->{notif}->read;
		$c->stash->{post} = $c->stash->{notif}->post;
		$c->forward('/post/permalink');
	}
	else {
		$c->res->redirect($c->req->referer || '/user/notifs');
	}
}

sub list :Path('/user/notifs') :Args(0) {
	my ($self, $c) = @_;

	$c->detach('/forbidden', [ $c->string('notUser') ]) unless $c->user;

	$c->stash->{notifs} = $c->user->notifs->search({}, {
		prefetch => [
			{ post => [qw/artist entry/] },
		],
		order_by => { -desc => 'me.created' },
	});

	push @{ $c->stash->{title} }, $c->string('notifs');
	$c->stash->{template} = 'notif/list.tt';
}

__PACKAGE__->meta->make_immutable;

1;
