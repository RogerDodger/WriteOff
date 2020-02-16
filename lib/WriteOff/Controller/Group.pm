package WriteOff::Controller::Group;
use Moose;
use namespace::autoclean;
use Scalar::Util qw/looks_like_number/;
use WriteOff::Mode qw/FIC/;
use WriteOff::Util qw/trim/;

BEGIN { extends 'Catalyst::Controller'; }

__PACKAGE__->config(model => 'Genre');

sub _fetch :ActionClass('~Fetch') {}

sub fetch :Chained('/') :PathPart('group') :CaptureArgs(1) {
   my ($self, $c) = @_;
   $c->forward('_fetch');
   $c->stash->{group} = $c->model('DB::Genre')->with_counts->find($c->stash->{genre}->id);
   $c->title_unshift($c->stash->{group}->name);
}

sub add :Path('new') :Args(0) {
   my ($self, $c) = @_;

   if ($c->req->method eq 'POST') {
      $c->csrf_assert;

      my $name = $c->paramo('groupname');
      $c->yuck('Name is required') if !length $name;

      my $descr = $c->paramo('descr');
      $c->yuck('Descr is required') if !length $descr;

      my $group = $c->model('DB::Genre')->new_result({
         name => substr($name, 0, $c->config->{len}{max}{title}),
         descr => substr($descr, 0, $c->config->{len}{max}{blurb}),
         owner_id => $c->user->active_artist_id,
         completion => 1,
      });

      $group->banner_write($c->req->upload('banner'))
         if defined $c->req->upload('banner');

      $group->insert;
      $c->log->info("Group %d created by %s: %s - %s",
         $group->id,
         $c->user->id_uri,
         $group->name,
         $group->descr,
      );

      $c->model('DB::SubGenre')->create({
         user_id => $c->user->id,
         genre_id => $group->id,
      });

      $c->flash->{status_msg} = $c->string('groupCreated');
      $c->res->redirect($c->uri_for_action('/group/view', [ $group->id_uri ]));
   }

   $c->title_push($c->string('new'), $c->string('groups'));
}

sub archive :Chained('fetch') :PathPart('archive') {
   my ($self, $c, $year) = @_;

   my $rs = $c->stash->{events}
         // $c->model('DB::Event')->search({ genre_id => $c->stash->{genre}->id });

   $c->stash->{maxYear} = $c->stash->{now}->year;
   $c->stash->{minYear} =
      eval { $rs->parse_datetime($rs->get_column('created')->min)->year } //
      $c->stash->{maxYear};

   $year = $c->stash->{maxYear} if
      !defined $year || !looks_like_number($year) ||
      $year < $c->stash->{minYear} || $year > $c->stash->{maxYear};

   $c->stash->{year} = $year;
   $c->stash->{events} = $rs->archive(DateTime->new(year => $year));
   $c->stash->{show_last_post} = 1;

   push @{ $c->stash->{title} }, $c->string('archive'), $year;
   $c->stash->{template} = 'group/archive.tt';
}

sub edit :Chained('fetch') :PathPart('edit') :Args(0) {
   my ($self, $c) = @_;

   $c->detach('/forbidden', [ $c->string('notGroupAdmin') ])
      if !$c->user->admins($c->stash->{group});

   if ($c->req->method eq 'POST') {
      $c->csrf_assert;

      my $name = $c->paramo('groupname');
      $c->stash->{group}->name(substr $name, 0, $c->config->{len}{max}{title})
         if length $name;

      my $descr = $c->paramo('descr');
      $c->stash->{group}->descr(substr $descr, 0, $c->config->{len}{max}{blurb})
         if length $descr;

      $c->stash->{group}->banner_write($c->req->upload('banner'))
         if defined $c->req->upload('banner');

      $c->stash->{group}->update;
      $c->log->info("Group %d updated by %s: %s - %s",
         $c->stash->{group}->id,
         $c->user->id_uri,
         $c->stash->{group}->name,
         $c->stash->{group}->descr,
      );

      $c->flash->{status_msg} = $c->string('groupUpdated');
      $c->res->redirect($c->uri_for_action('/group/view', [ $c->stash->{group}->id_uri ]));
   }

   $c->title_push_s('edit');
}

sub index :Path('/groups') :Args(0) {
   my ($self, $c) = @_;

   my $rs = $c->model('DB::Genre')->with_counts;
   $c->stash->{promoted} = $rs->search({ promoted => 1 });
   $c->stash->{established} = $rs->search({ established => 1, promoted => 0 });
   $c->stash->{new} = $rs->search({ established => 0 });

   my %membership = map { $_->genre_id => 1 } $c->user->active_artist->artist_genre;
   $c->stash->{member} = sub { defined $_[0] && $membership{$_[0]} };

   $c->title_push_s('groups');
}

sub join :Chained('fetch') :PathPart('join') :Args(0) {
   my ($self, $c) = @_;

   $c->user_assert;
   $c->csrf_assert;

   my %o = (
      artist_id => $c->user->active_artist_id,
      genre_id => $c->stash->{genre}->id,
      role => 'user',
   );

   my $rs = $c->model('DB::ArtistGenre');
   if (!$c->user->owns($c->stash->{genre}) && !$rs->find($o{artist_id}, $o{genre_id})) {
      $rs->create(\%o);
      $c->model('DB::SubGenre')->find_or_create({
         user_id => $c->user->id,
         genre_id => $o{genre_id},
      });
      $c->stash->{genre}->recalc_completion($c->config->{group_min_size});
   }

   $c->res->redirect($c->req->referer
      || $c->uri_for_action('view', [ $c->stash->{genre}->id_uri ]));
}

sub leave :Chained('fetch') :PathPart('leave') :Args(0) {
   my ($self, $c) = @_;

   $c->user_assert;
   $c->csrf_assert;

   if ( my $member = $c->model('DB::ArtistGenre')->find(
         $c->user->active_artist_id, $c->stash->{genre}->id) ) {

      $member->leave($c->config->{group_min_size});
   }

   $c->res->redirect($c->req->referer
      || $c->uri_for_action('view', [ $c->stash->{genre}->id_uri ]));
}

sub members :Chained('fetch') :PathPart('members') :Args(0) {
   my ($self, $c) = @_;
   $c->stash->{members} = $c->stash->{group}->members->index;
}

sub member :Chained('fetch') :PathPart('member') :CaptureArgs(1) {
   my ($self, $c, $aid) = @_;

   $aid =~ /^(\d+)/ and
   $c->stash->{member} = $c->model('DB::ArtistGenre')->find($1, $c->stash->{group}->id)
      or $c->detach('/default');
}

sub member_leave :Chained('member') :PathPart('leave') :Args(0) {
   my ($self, $c) = @_;
   $c->detach('/default') if $c->req->method ne 'POST';
   $c->user_assert;
   $c->csrf_assert;

   my $artist = $c->stash->{member}->artist;
   $c->detach('/forbidden') if $artist->user_id != $c->user->id;

   $c->stash->{member}->leave($c->config->{group_min_size});
   $c->flash->{status_msg} =
      $c->string('artistLeftGroup', $artist->name, $c->stash->{group}->name);

   $c->res->redirect($c->req->referer || $c->uri_for_action('/user/groups'));
}

sub schedule :Chained('fetch') :PathPart('schedule') :Args(0) {
   my ($self, $c) = @_;
   $c->stash->{schedules} = $c->stash->{group}->schedules->index;
}

sub scoreboard :Chained('fetch') :PathPart('scoreboard') {
   my ($self, $c, $mname) = @_;
   $c->stash->{genre} = $c->stash->{group};
   $c->stash->{mode} = WriteOff::Mode->find($mname) // FIC;
   $c->stash->{mUrl} = $c->uri_for_action($c->action, [ $c->stash->{group}->id_uri ], '%s');
   $c->forward('/scoreboard/view');
}

sub view :Chained('fetch') :PathPart('') :Args(0) {
   my ($self, $c) = @_;

   $c->stash->{events} //=
      $c->model('DB::Event')->search({ genre_id => $c->stash->{group}->id });
   $c->stash->{active} = $c->stash->{events}->active;
   $c->stash->{recent} = $c->stash->{events}->recent;
   $c->stash->{forum} = $c->stash->{events}->forum;
   $c->stash->{show_last_post} = 1;

   $c->stash->{template} = 'group/view.tt';
}

sub unsub :Chained('fetch') :PathPart('unsub') :Args(0) {
   my ($self, $c) = @_;
   $c->detach('/default') if $c->req->method ne 'POST';
   $c->user_assert;
   $c->csrf_assert;

   if ($c->stash->{group}->owner->user_id == $c->user->id) {
      $c->flash->{error_msg} = $c->string('cantUnsubOwnGroup');
   }
   else {
      $c->user->artists
         ->related_resultset('artist_genre')
         ->search({ genre_id => $c->stash->{group}->id })
         ->delete;

      $c->model('DB::SubGenre')->find($c->user->id, $c->stash->{group}->id)->delete;

      $c->stash->{group}->recalc_completion($c->config->{group_min_size});

      $c->flash->{status_msg} =
         $c->string('unsubbedGroup', $c->stash->{group}->name);
   }

   $c->res->redirect($c->req->referer || $c->uri_for_action('/user/groups'));
}

__PACKAGE__->meta->make_immutable;

1;
