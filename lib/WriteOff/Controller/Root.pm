package WriteOff::Controller::Root;
use Moose;
use namespace::autoclean;
use feature 'state';
use Scalar::Util qw/looks_like_number/;
require WriteOff::DateTime;

no warnings "uninitialized";

BEGIN { extends 'Catalyst::Controller' }

__PACKAGE__->config(namespace => '');

sub auto :Private {
   my ( $self, $c ) = @_;

   # This is necessary because of a bug/exploit whereby requests hitting the
   # website with a different $c->req->base were then having their results
   # cached. The cached results would then appear to regular users which
   # point to another domain. Not good!
   #
   # Also, this makes emails sent out point to the right domain, rather than
   # localhost:<port>.
   if (!$c->debug && $c->config->{domain}) {
      $c->req->base(URI->new('//' . $c->config->{domain} . '/'));
   }
   else {
      $c->req->base(URI->new('//' . $c->req->base->authority));
   }

   if ($c->debug) {
      if ($c->req->param('login')) {
         $c->user(
            $c->model('DB::User')->find({ name_canonical => lc $c->req->params->{login} })
         );
      }
   }

   $c->stash(
      now        => WriteOff::DateTime->now,
      title      => [],
      ext        => scalar($c->req->param('format')) || 'html',
      csrf_token => $c->csrf_token,
      messages   => [],
   );

   my $so = $c->req->uri->host eq eval { URI->new( $c->req->referer )->host };

   $c->log->_log("access", "[%s] %s (%s) - %s" . ( $so ? "" : " - %s" ),
      $c->req->method,
      $c->req->address,
      ( $c->user ? $c->user->username : 'guest' ),
      $c->req->uri->path,
      ( $so ? () : $c->req->referer || 'no referer'),
   );

   if ($c->req->method eq 'POST') {
      $c->req->{parameters} = {} if $c->config->{read_only};
      $c->detach('index') if !$so;
   }

   if ($c->req->header('x-requested-with') eq 'XMLHttpRequest') {
      $c->stash->{ajax} = 1;
      $c->stash->{wrapper} = 'wrapper/bare.tt';
   }

   if ($c->config->{read_only}) {
      push @{ $c->stash->{messages} }, 'The site is currently in read-only mode.';
   }

   if (!$c->session('introduced')) {
      $c->session->{introduced} = 1 if $c->user;
   }

   1;
}

# sub hang :Local :Args(0) {
# 	my $n = 0;
# 	while (1) {
# 		$n++;
# 	}
# }

sub awardmock :Local {
   my ($self, $c) = @_;

   $c->stash->{awards} = \@WriteOff::Award::ORDERED;

   $c->stash->{template} = 'root/awardmock.tt';
}

sub index :Path :Args(0) {
   my ( $self, $c ) = @_;

   $c->stash->{events} = $c->model('DB::Event')->promoted;
   $c->forward('/group/view');
}

sub archive :Local {
   my ( $self, $c, $year ) = @_;

   $c->stash->{events} = $c->model('DB::Event')->promoted;
   $c->forward('/group/archive');
}

sub faq :Local :Args(0) {
   my ( $self, $c ) = @_;

   $c->stash->{document} = $c->document('faq');

   push @{ $c->stash->{title} }, 'FAQ';
   $c->stash->{template} = 'root/document.tt';
}

sub default :Path {
   my ( $self, $c ) = @_;

   state $renamed = [
      qr{^/art/(.+)$},             sub { "/pic/$1" },
      qr{^/event/(.+?)/art/(.+)$}, sub { "/event/$1/pic/$2" },
      qr{^/static/art/(.+)$},      sub { "/static/pic/$1" },
   ];

   for (my $i = 0; $i <= $#$renamed; $i += 2) {
      if ($c->req->uri->path =~ $renamed->[$i]) {
         $c->res->redirect($c->uri_for($renamed->[$i+1]->()), 302);
         $c->detach;
      }
   }

   $c->stash->{title} = [ $c->string('404') ];
   $c->stash->{template} = 'root/404.tt';
   $c->res->status(404);
}

sub forbidden :Private {
   my ( $self, $c, $msg ) = @_;

   $c->stash->{forbidden_msg} = $msg if $msg;

   $c->stash->{title} = [ $c->string('403') ];
   $c->stash->{template} = 'root/403.tt';
   $c->res->status(403);
}

sub error :Private {
   my ( $self, $c, $msg ) = @_;

   if (!defined $c->stash->{error}) {
      $c->stash->{error} = $msg // $c->string('unknownError');
   }

   if ($c->res->status == 200) {
      $c->res->status(400);
   }

   push @{ $c->stash->{title} }, $c->string('error');
   $c->stash->{template} = 'root/error.tt';
}

sub tos :Local :Args(0) {
   my ( $self, $c ) = @_;

   $c->stash->{document} = $c->document('tos');

   push @{ $c->stash->{title} }, $c->stash->{document}{title};
   $c->stash->{template} = 'root/document.tt';
}

sub rights :Local :Args(0) {
   my ($self, $c) = @_;

   $c->stash->{document} = $c->document('rights');

   push @{ $c->stash->{title} }, $c->stash->{document}{title};
   $c->stash->{template} = 'root/document.tt';
}

sub intro :Local :Args(0) {
   my ($self, $c) = @_;

   $c->stash->{document} = $c->document('intro');
   $c->session->{introduced} = 1;

   push @{ $c->stash->{title} }, $c->stash->{document}{title};
   $c->stash->{template} = 'root/document.tt';
}

sub style :Local :Args(0) {
   my ($self, $c) = @_;

   $c->stash->{document} = $c->document('style');

   push @{ $c->stash->{title} }, $c->stash->{document}{title};
   $c->stash->{template} = 'root/document.tt';
}

sub robots :Path('/robots.txt') :Args(0) {
   my ($self, $c) = @_;

   my $storys = $c->model('DB::Story')->search(
      { indexed => { "!=" => 1 } },
      { columns => [ qw/me.id entry.title/ ], prefetch => 'entry' },
   );

   my $body = "User-agent: *\n";
   while (my $story = $storys->next) {
      $body .= "Disallow: /fic/" . $story->id_uri . "\n";
   }

   $c->res->body($body);
   $c->res->content_type('text/plain; charset=utf-8');
}

sub assert_admin :Private {
   my ( $self, $c, $msg ) = @_;

   $c->user->admin or $c->detach('/forbidden', [ $c->string('notAdmin') ]);
}

sub check_csrf_token :Private {
   my ($self, $c) = @_;

   $c->req->param('csrf_token') eq $c->csrf_token
      or $c->detach('/error', [ $c->string('csrfDetected') ]);
}

sub prepare_thread :Private {
   my ($self, $c, $posts) = @_;

   if ($c->req->param('dry') && $c->req->param('page')) {
      $c->page;
      $c->res->body('Okay');
      $c->detach;
   }

   $c->stash->{posts} = $posts->thread($c->page);
   $c->stash->{votes} = $posts->vote_map($c->user);
}

sub strum :Private {
   my ( $self, $c ) = @_;

   return if !defined $c->res->{body};

   my $strum = $c->config->{strum} or return;
   while (my($key, $strum) = each %$strum) {
      while((my $index = CORE::index $c->res->{body}, $key) >= 0) {
         substr($c->res->{body}, $index, length $key) = $strum;
      }
   }
}

sub render : ActionClass('RenderView') {}

sub end :Private {
   my ( $self, $c ) = @_;

   if (!$c->debug && $c->has_errors) {
      my $msg = join "\n", @{ $c->error };
      $c->log->error($_) for @{ $c->error };
      $c->error(0);
      $c->res->location(undef);
      $c->res->code(500);
      $c->forward('error', [ $msg ]);
   }

   $c->forward('render');
   $c->forward('strum') if $c->config->{strum_ok} && rand > 0.5;
   $c->fillform( $c->stash->{fillform} ) if defined $c->stash->{fillform};
}

=head1 AUTHOR

Cameron Thornton E<lt>cthor@cpan.orgE<gt>

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
