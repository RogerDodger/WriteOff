package WriteOff::Controller::Group;
use Moose;
use namespace::autoclean;
use Scalar::Util qw/looks_like_number/;
use WriteOff::Mode qw/FIC/;

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

   $c->title_push($c->string('new'), $c->string('groups'));
}

sub archive :Chained('fetch') :PathPart('archive') {
   my ($self, $c, $year) = @_;

   my $rs = $c->stash->{events} // $c->stash->{group}->events;
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

}

sub index :Path('/groups') :Args(0) {
   my ($self, $c) = @_;

   my $rs = $c->model('DB::Genre')->with_counts;
   $c->stash->{promoted} = $rs->search({ promoted => 1 });
   $c->stash->{established} = $rs->search({ established => 1, promoted => 0 });
   $c->stash->{new} = $rs->search({ established => 0 });

   my %membership = map { $_->genre_id => 1 } $c->user->active_artist->artist_genre;
   $c->stash->{member} = sub { defined $_[0] && $membership{$_[0]} };

   $c->title_push($c->string('groups'));
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
   $rs->create(\%o) if !$rs->find($o{artist_id}, $o{genre_id});

   $c->res->redirect($c->req->referer
      || $c->uri_for_action('view', [ $c->stash->{genre}->id_uri ]));
}

sub leave :Chained('fetch') :PathPart('leave') :Args(0) {
   my ($self, $c) = @_;

   $c->user_assert;
   $c->csrf_assert;

   my $row = $c->model('DB::ArtistGenre')->find(
      $c->user->active_artist_id, $c->stash->{genre}->id);

   $row->delete if $row;

   $c->res->redirect($c->req->referer
      || $c->uri_for_action('view', [ $c->stash->{genre}->id_uri ]));
}

sub members :Chained('fetch') :PathPart('members') :Args(0) {
   my ($self, $c) = @_;
   $c->stash->{members} = $c->stash->{group}->members->index;
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

   $c->stash->{events} //= $c->stash->{group}->events;
   $c->stash->{active} = $c->stash->{events}->active;
   $c->stash->{last} = $c->stash->{events}->last_ended;
   $c->stash->{forum} = $c->stash->{events}->forum;
   $c->stash->{show_last_post} = 1;

   $c->stash->{template} = 'group/view.tt';
}

__PACKAGE__->meta->make_immutable;

1;
