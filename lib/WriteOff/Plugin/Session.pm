use 5.01;
package WriteOff::Plugin::Session;

# Largely adapted from--
#
#    Catalyst::Plugin::Session
#    Catalyst::Plugin::Session::Store::Cookie
#    Catalyst::Plugin::Session::Store::State
#
# Changes are removing the need for a separate store and state cookies, and
# enabling httponly, secure, and samesite on the store cookie.

use Moose::Role;

use Crypt::URandom qw/urandom/;
use Math::Random::ISAAC::XS;
use Session::Storage::Secure;

use namespace::autoclean;

my @session_data_accessors = qw/
   _session
   _session_dirty
   _flash
/;

has $_ => (is => 'rw') for @session_data_accessors;

my $_conf;
my $_secure_store;
my $_rng;
my $DAY = 60 * 60 * 24;

after setup => sub {
   my $c = shift;

   $_conf = $c->config->{'Plugin::Session'} // $c->config->{session};
   $_conf = {} if ref $_conf ne 'HASH';

   $_conf->{cookie_name} //= Catalyst::Utils::appprefix($c);
   $_conf->{expires} //= $DAY * 60;
   $_conf->{secure} //= $c->config->{https};
   $_conf->{httponly} //= 1;
   $_conf->{samesite} //= 'Lax';

   $_conf->{secret} //= $_conf->{storage_secret_key}
      || die "'storage_secret_key' configuration param for 'Plugin::Session' is missing!";
   $_conf->{sereal_encoder_options} //= { snappy => 1, stringify_unknown => 1 };
   $_conf->{sereal_decoder_options} //= { validate_utf8 => 1 };

   $_rng = Math::Random::ISAAC::XS->new( map { unpack( "N", urandom(4) ) } 1 .. 256);
   $_secure_store =
      Session::Storage::Secure->new(
         secret_key => $_conf->{secret},
         sereal_encoder_options => $_conf->{sereal_encoder_options},
         sereal_decoder_options => $_conf->{sereal_decoder_options},
      );
};

after prepare_action => sub {
   my $c = shift;
   return if $c->_static_file;

   my $cookie = $c->req->cookie($_conf->{cookie_name});
   my $session = defined($cookie) && $_secure_store->decode($cookie->value);

   if (ref $session eq 'HASH') {
      # Re-set the cookie if it's over a day old
      my (undef, $expires) = split $_secure_store->separator, $cookie->value;
      my $age = time + $_conf->{expires} - $expires;
      $c->log->debug("Cookie age: $age");
      if (abs($age) > $DAY) {
         $c->_session_dirty(1);
      }

      # Move flash to the stash and delete it from the session
      if (my $flash = delete $session->{__flash}) {
         $c->stash($flash);
         $c->_session_dirty(1);
      }

      $c->_session($session);
   }
};

before finalize_headers => sub {
   my $c = shift;
   return if $c->_static_file;

   if ($c->_session_dirty) {
      my $expires = time + $_conf->{expires};
      my $value = $_secure_store->encode($c->_session, $expires);

      $c->log->debug("Plugin::Session - Writing new session cookie: \n  $value");

      $c->res->cookies->{$_conf->{cookie_name}} = CGI::Simple::Cookie->new(
         -name => $_conf->{cookie_name},
         -value => $value,
         -expires => $expires,
         -secure => $_conf->{secure},
         -httponly => $_conf->{httponly},
         -samesite => $_conf->{samesite},
      );
   }
};

before finalize_body => sub {
   my $c = shift;
   $c->$_(undef) for @session_data_accessors;
};

sub session {
   my $c = shift;

   if (!$c->_session) {
      $c->_session({ __sessionid => _rng_digest() });
   }

   my $data = $c->_session;

   if (@_ == 1 && ref $_[0] eq '') {
      return $data->{$_[0]};
   }
   else {
      $c->_session_dirty(1);
      _assign_maybe($data, @_);
      return $data;
   }
}

sub sessionid {
   shift->session('__sessionid');
}

sub flash {
   my $c = shift;
   my $data = ($c->session->{__flash} //= {});
   _assign_maybe($data, @_);
   $data;
}

sub _assign_maybe {
   my $data = shift;

   my $new_values = @_ > 1 ? { @_ } : $_[0];
   if (ref $new_values eq 'HASH') {
      for my $key (keys %$new_values) {
         $data->{$key} = $new_values->{$key};
      }
   }
}

sub _rng_digest {
   Digest->new('MD5')->add($_rng->irand)->hexdigest;
}

1;
