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

	my $rightEntry = $entry eq ($c->stash->{post}->entry_id // '');
	my $rightEvent = $event eq $c->stash->{post}->event_id;

	my $thread = !$c->stash->{post}->entry || !$entry && $rightEvent
		? $c->stash->{post}->event->posts
		: $c->stash->{post}->entry->posts;

	$c->stash->{num} = $thread->num_for($c->stash->{post});
	$c->stash->{page} = $c->page_for($c->stash->{num});
	$c->stash->{page} = 0 if !$rightEvent || $entry && !$rightEntry;

	my $vote = $c->model('DB::PostVote')->find($c->user->id, $c->stash->{post}->id);
	$c->stash->{vote} = $vote && $vote->value;

	$c->stash->{template} = 'post/single.tt';
	push @{ $c->stash->{title} }, $c->string('postN', $c->stash->{post}->id);
}

sub add :Local {
	my ($self, $c) = @_;

	return unless $c->user->active_artist_id;
	$c->forward('/check_csrf_token');

	my $cache = $c->config->{limitCache};
	my $key = "post" . $c->user->id;
	if ($cache->get($key)) {
		$c->stash->{refresh} = $c->uri_for_action('/post/latest');
		$c->stash->{status_msg} = $c->string('doublePost');
		$c->stash->{template} = 'root/blank.tt';
		return;
	}
	$cache->set($key, 1);

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
	$c->stash->{event}->update({ last_post => $post });

	$c->res->redirect($c->uri_for_action('/post/permalink', [ $post->id ]));
}

sub edit :Chained('fetch') :PathPart('edit') :Args(0) {
	my ($self, $c) = @_;

	$c->detach('/default')   if $c->stash->{post}->deleted;
	$c->detach('/forbidden') if !$c->user->can_edit($c->stash->{post});
	$c->forward('do_edit')   if $c->req->method eq 'POST';

	$c->stash->{template} = 'post/edit.tt';
	push @{ $c->stash->{title} }, $c->string('editPost');
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
		$c->forward('permalink');
	}
}

sub delete :Chained('fetch') :PathPart('delete') :Args(0) {
	my ($self, $c) = @_;

	$c->detach('/default')   unless $c->req->method eq 'POST';
	$c->detach('/forbidden') unless $c->user->can_edit($c->stash->{post});
	$c->forward('/check_csrf_token');

	$c->stash->{post}->update({ deleted => int !$c->stash->{post}->deleted });

	$c->forward('permalink');
}

sub latest :Local :Args(0) {
	my ($self, $c) = @_;

	my $post = $c->user->active_artist->posts->order_by({ -desc => 'created' })->first
		or $c->detach('/default');

	$c->res->redirect($c->uri_for_action('/post/permalink', [ $post->id ]));
}

sub _vote :ActionClass('~Vote') {}

sub vote :Chained('fetch') :PathPart('vote') :Args(0) {
	my ($self, $c) = @_;
	$c->detach('/default') if $c->stash->{post}->artist->user_id == $c->user_id || $c->stash->{post}->deleted;
	$c->stash->{redirect} = $c->uri_for_action('/post/permalink', [ $c->stash->{post}->id ]);
	$c->forward('_vote');
}

__PACKAGE__->meta->make_immutable;

1;
