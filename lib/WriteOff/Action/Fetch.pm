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
      $c->log->debug($c->action);
      # $c->req->args doesn't have access to arguments/captures for any
      # chained actions, so we can't use that and uri_for to construct the
      # redirect nicely. Instead, we need to mangle the raw URI directly.
      my $new_arg = $desired_arg . ($ext // '');
      my $uri = $c->req->uri->clone;
      $uri->path( $uri->path =~ s{/\Q$arg\E}{/$new_arg}xr );
      $c->res->redirect($uri);
      $c->detach;
   }

   if ($item->can('title')) {
      push @{ $c->stash->{title} }, $item->title;
   }

   if (defined $ext) {
      $c->stash->{ext} = substr($ext, 1);
   }
}

1;
