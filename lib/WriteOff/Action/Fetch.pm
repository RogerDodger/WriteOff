package WriteOff::Action::Fetch;

use base 'Catalyst::Action';
use 5.014;

sub execute {
   my (undef, $self, $c, $arg) = @_;

   unless ($arg =~ /^(\d+)(.*?)(\.[a-z]+)?$/) {
      $c->detach('/default');
   }
   my ($id, $desc, $ext) = ($1, $2, $3);

   my $model = $self->config->{model} || (ref $self || $self) =~ s/.*:://r;
   my $key   = $self->config->{fetch} || lc $model;

   my $item = $c->model('DB')->resultset($model)->find($id);
   if (defined $item) {
      $c->stash->{$key} = $item;
   }
   else {
      $c->detach('/default');
   }

   my $desired_arg = $item->can('id_uri') ? $item->id_uri : $item->id;
   if ($id . $desc ne $desired_arg) {
      $c->req->args->[0] = $desired_arg . ($ext // '');
      $c->res->redirect(
         $c->uri_for($c->action, $c->req->args, $c->req->params)
      );
      $c->detach;
   }

   if ($item->can('title')) {
      push @{ $c->stash->{title} }, $item->title;
   }

   if (defined $ext) {
      $c->stash->{format} = substr($ext, 1);
   }
}

1;
