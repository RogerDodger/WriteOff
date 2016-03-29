package WriteOff::Controller::Post;
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller'; }

sub fetch :Chained('/') :PathPart('post') :CaptureArgs(1) :ActionClass('~Fetch') {}

sub permalink :Chained('fetch') :PathPart('') :Args(0) {
	my ($self, $c) = @_;

	my $uri = $c->uri_for_action(
		$c->stash->{post}->entry
			? ($c->stash->{post}->entry->view, [ $c->stash->{post}->entry->id_uri ])
			: ('/event/permalink', [ $c->stash->{post}->event->id_uri ])
	);

	$c->stash->{entry} = $c->stash->{post}->entry;
	$c->stash->{event} = $c->stash->{post}->event;
	$c->page($c->page_for($c->stash->{post}->num));

	$c->res->redirect($uri . "#" . $c->stash->{post}->id);
}

sub view :Chained('fetch') :PathPart('view') :Args(0) {
	my ($self, $c) = @_;

	my $entry = $c->req->param('entry_id') // '';
	my $event = $c->req->param('event_id') // '';

	my $wrongEntry = $c->stash->{post}->entry_id && $entry && $c->stash->{post}->entry_id ne $entry;
	my $rightEvent = $event eq $c->stash->{post}->event_id;

	my $thread = !$c->stash->{post}->entry || !$entry && $rightEvent
		? $c->stash->{post}->event->posts
		: $c->stash->{post}->entry->posts;

	$c->stash->{num} = $thread->num_for($c->stash->{post});
	$c->stash->{page} = $c->page_for($c->stash->{num});
	$c->stash->{page} = 0 if !$rightEvent || $wrongEntry;

	$c->stash->{template} = 'post/single.tt';
	push $c->stash->{title}, $c->string('postN', $c->stash->{post}->id);
}

sub add :Local {
	my ($self, $c) = @_;

	return unless $c->user->active_artist_id;
	$c->forward('/check_csrf_token');

	if ($c->req->param('event') =~ /(\d+)/) {
		$c->stash->{event} = $c->model('DB::Event')->find($1);
	}

	$c->detach('/error') unless $c->stash->{event} && $c->stash->{event}->commenting;

	my %post = (
		artist_id => $c->user->active_artist_id,
		event_id => $c->stash->{event}->id,
		body => $c->req->param('body') // '',
		body_render => '',
	);

	if ($c->req->param('entry') =~ /(\d+)/) {
		if ($c->stash->{entry} = $c->model('DB::Entry')->find($1)) {
			$c->detach('/error') unless $c->stash->{event}->fic_gallery_opened;
			$post{entry_id} = $c->stash->{entry}->id;
		}
	}

	my $post = $c->model('DB::Post')->create(\%post)->render;

	$c->res->redirect($c->uri_for_action('/post/permalink', [ $post->id ]));
}

sub edit :Chained('fetch') :PathPart('edit') :Args(0) {
	my ($self, $c) = @_;

	if ($c->user->can_edit($c->stash->{post})) {
		$c->forward('do_edit') if $c->req->method eq 'POST';
	}
	else {
		$c->detach('/forbidden');
	}

	$c->stash->{template} = 'post/edit.tt';
	push $c->stash->{title}, $c->string('editPost');
}

sub do_edit :Private {
	my ($self, $c) = @_;

	$c->forward('/check_csrf_token');

	my $post = $c->stash->{post};

	$post->body($c->req->param('body') // '');
	$post->render;

	if ($c->stash->{ajax}) {
		$c->res->body($post->body_render);
	}
	else {
		$c->res->redirect($c->uri_for_action('/post/permalink', [ $post->id ]));
	}
}

sub _vote :ActionClass('~Vote') {}

sub vote :Chained('fetch') :PathPart('vote') :Args(0) {
	my ($self, $c) = @_;
	$c->stash->{redirect} = $c->uri_for_action('/post/permalink', [ $c->stash->{post}->id ]);
	$c->forward('_vote');
}

__PACKAGE__->meta->make_immutable;

1;
