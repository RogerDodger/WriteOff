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

   $c->title_push($c->string('groups'));
}

sub join :Chained('fetch') :PathPart('join') :Args(1) {

}

sub schedule :Chained('fetch') :PathPart('schedule') :Args(0) {

}

sub scoreboard :Chained('fetch') :PathPart('scoreboard') :Args(0) {

}

sub view :Chained('fetch') :PathPart('') :Args(0) {

}

__PACKAGE__->meta->make_immutable;

1;
