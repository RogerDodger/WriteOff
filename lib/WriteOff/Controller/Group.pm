package WriteOff::Controller::Group;
use Moose;
use namespace::autoclean;

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

sub schedule :Chained('fetch') :PathPart('schedule') :Args(0) {

}

sub scoreboard :Chained('fetch') :PathPart('scoreboard') :Args(0) {

}

sub view :Chained('fetch') :PathPart('') :Args(0) {

}

__PACKAGE__->meta->make_immutable;

1;
