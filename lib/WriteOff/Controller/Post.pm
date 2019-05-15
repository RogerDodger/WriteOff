package WriteOff::Controller::Post;
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller'; }

use WriteOff::Notif qw/:all/;

sub fetch :Chained('/') :PathPart('post') :CaptureArgs(1) :ActionClass('~Fetch') {}

sub permalink :Chained('fetch') :PathPart('') {
   my ($self, $c, $ctx) = @_;
   my $post = $c->stash->{post};

   my %view;
   $view{event} = '/event/permalink' if $post->event_id;
   $view{entry} = $post->entry->view if $post->entry_id;

   $ctx //= '';
   for (qw/entry event/) {
      $ctx = $_ if !exists $view{$ctx};
   }

   if (exists $view{$ctx}) {
      $c->stash->{entry} = $post->entry if $ctx eq 'entry';
      $c->stash->{event} = $post->event;

      $c->page($c->page_for($post->num($post->$ctx->posts_rs)));

      my $url = $c->uri_for_action($view{$ctx}, [ $post->$ctx->id_uri ]);
      $c->res->redirect($url . "#" . $post->id);
   }
   else {
      $c->res->redirect($c->uri_for_action('/post/view', [ $post->id ]));
   }
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
   $c->stash->{votes} = { $c->stash->{post}->id => $vote && $vote->value };

   $c->stash->{template} = 'post/view.tt';
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
         my $meth = $c->stash->{entry}->mode . '_gallery_opened';

         if ($c->stash->{entry}->event_id != $c->stash->{event}->id) {
            $c->detach('/error', [ 'Entry not in event' ]);
         }
         elsif (!$c->stash->{event}->$meth) {
            $c->detach('/error', [ 'Gallery not opened yet' ]);
         }
         else {
            $post{entry_id} = $c->stash->{entry}->id;
         }
      }
   }

   if (defined(my $role = $c->req->param('role'))) {
      $post{role} = $role if grep { $_ eq $role } @{ $c->post_roles };
   }

   my $post = $c->model('DB::Post')->create(\%post)->render;
   $c->stash->{event}->update({ last_post => $post });

   # We don't want to notify someone of the same post multiple times, so we
   # keep track of who has already been notified.
   #
   # Notifs have precedence of REPLY MENTION COMMENT, such that, for example,
   # if a post would proc a REPLY and a COMMENT notif for the same user, that
   # user will receive only a REPLY notif.
   #
   # This behaviour isn't defined in the Notif class since it's merely a
   # result of the order in which the notifs are created here.
   #
   # Also, don't notify someone of their own post.
   my %notifd = ( $c->user->id => 1 );
   my @notifs;

   my %base = (
      post_id => $post->id,
      created => $c->model('DB::Notif')->format_datetime($post->created),
   );

   for my $parent ($post->parents->search({}, { prefetch => 'artist' })->all) {
      next if $notifd{$parent->artist->user_id}++;

      push @notifs, {
         user_id => $parent->artist->user_id,
         notif_id => REPLY()->id,
      };
   }

   if (my $entry = $c->stash->{entry}) {
      if (!$notifd{$entry->user_id}++) {
         push @notifs, {
            user_id => $entry->user_id,
            notif_id => COMMENT()->id,
         };
      }
   }

   $c->model('DB::Notif')->populate([ map { { %$_, %base } } @notifs ]);

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

   $c->detach('/forbidden')
      if $c->stash->{post}->artist->user_id == $c->user_id || $c->stash->{post}->deleted;

   $c->forward('_vote');

   $c->res->redirect($c->uri_for_action('/post/permalink', [ $c->stash->{post}->id ]))
      if !defined $c->res->body;
}

__PACKAGE__->meta->make_immutable;

1;
