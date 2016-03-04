package WriteOff::Controller::Ballot;
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller'; }

sub _fetch :ActionClass('~Fetch') {}

sub fetch :Chained('/') :PathPart('ballot') :CaptureArgs(1) {
	my ($self, $c) = @_;
	$c->forward('_fetch');
	$c->stash->{event} = $c->stash->{ballot}->event;
}

sub view :Chained('fetch') :PathPart('') Args(0) {
	my ($self, $c) = @_;

	$c->detach('/forbidden') unless $c->user->id == $c->stash->{ballot}->user_id;

	$c->stash->{votes} = $c->stash->{ballot}->votes->ordered->search({}, {
		prefetch => { entry => 'round' },
	});

	push $c->stash->{title}, $c->string($c->stash->{ballot}->round->name . 'Ballot');
	$c->stash->{template} = 'ballot/view.tt';
}

__PACKAGE__->meta->make_immutable;

1;
