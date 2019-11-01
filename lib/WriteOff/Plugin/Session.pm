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

use Carp qw/croak/;
use Crypt::URandom qw/urandom/;
use DBI;
use File::Spec;
use JSON;
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
my $_flash_dbh;
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

   $_flash_dbh = DBI->connect('dbi:SQLite:' .
      File::Spec->catfile(File::Spec->tmpdir, $_conf->{cookie_name} . '-flash.db'),
      "", "", {
         sqlite_unicode => 1,
         AutoCommit => 1,
      },
   );

   $_flash_dbh->do(q{
      CREATE TABLE IF NOT EXISTS flash (
         key TEXT PRIMARY KEY,
         value TEXT,
         expires INTEGER
      );
   }) or croak $_flash_dbh->errstr;
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

      # Try and find flash data if __flash is in the session
      if (delete $session->{__flash}) {
         if (defined( my $data = _flash_get($session->{__sessionid}) )) {
            $c->stash($data);
         }
         $c->_session_dirty(1);
      }

      $c->_session($session);
   }
};

before finalize_headers => sub {
   my $c = shift;
   return if $c->_static_file;

   if (defined $c->_flash) {
      $c->session->{__flash} = 1;
      _flash_set($c->sessionid, $c->_flash);
   }

   if ($c->_session_dirty) {
      my $expires = time + $_conf->{expires};
      my $value = $_secure_store->encode($c->_session, $expires);

      $c->log->debug(
         "Plugin::Session - Writing new session cookie:\n  $value\n  " . encode_json($c->_session));

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

sub clean_flash {
   my $c = shift;
   my $sth = $_flash_dbh->prepare_cached(q{ DELETE FROM flash WHERE expires < ? });
   $sth->execute(time) or croak $sth->errstr;
}

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
   my $data = ($c->_flash // {});
   $c->_flash($data);
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

sub _flash_set {
   my ($k, $v) = @_;

   my $sth = $_flash_dbh->prepare_cached(q{ INSERT OR REPLACE INTO flash VALUES (?, ?, ?) });
   $sth->execute($k, encode_json($v), time + $DAY) or croak $sth->errstr;
}

sub _flash_get {
   my ($k) = @_;

   my $sel = $_flash_dbh->prepare_cached(q{ SELECT value FROM flash WHERE key = ? });
   $sel->execute($k) or croak $sel->errstr;
   my $result = $sel->fetchall_arrayref;
   my $v = $result->[0]->[0];

   if (defined $v) {
      my $del = $_flash_dbh->prepare_cached(q{ DELETE FROM flash WHERE key = ? });
      $del->execute($k) or croak $del->errstr;
      return decode_json($v);
   }

   undef;
}


sub _rng_digest {
   Digest->new('MD5')->add($_rng->irand)->hexdigest;
}

1;
