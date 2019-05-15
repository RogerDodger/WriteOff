package WriteOff::Command;

use strict;
use warnings;
use feature ':5.10';

use Carp qw/croak/;
use Module::Find qw/usesub/;
use Try::Tiny;
use Text::Wrap qw/wrap/;

my %commands;

sub abort;

sub import {
	my $class = shift;

	my $caller = caller;
   return unless $caller =~ /^WriteOff::Command/;

	strict->import;
	warnings->import;
	feature->import(':5.10');

	no strict 'refs';
   *{"${caller}::abort"} = *abort;
   *{"${caller}::config"} = *config;
   *{"${caller}::db"} = *db;
   *{"${caller}::dbh"} = *dbh;
   *{"${caller}::schema"} = *schema;

   *{"${caller}::can"} = sub {
      my ($verb, $sub, %opt) = @_;

      my $noun = $caller =~ s/^.+:://r;
      my $model = ${"${caller}::MODEL"} // ucfirst $noun;

      my $fetch = $opt{fetch} // 1;

      my $usage = "$noun $verb";
      $usage .= sprintf " %s", uc $model if $fetch eq '1' || $fetch eq 'all';
      $usage .= sprintf " [%s]", uc $model if $fetch eq 'maybe';

      my @opts = ();
      my @pairs = @{ $opt{with} // [] };
      while (@pairs) {
         push @opts, [ shift @pairs, shift @pairs ],
      }

      for my $opt (@opts) {
         $usage .= sprintf " %s", uc $opt->[0];
         $usage .= sprintf "=%s", $opt->[1] if defined $opt->[1];
      }

      my $help = $opt{which} // croak "No help given for $verb";
      $help =~ s/\r\n|\n\r/\n/g;
      $help = [ split /\n\n/, $help ];
      $_ =~ s/^\s+//g for @$help;
      $_ =~ s/\s+/ /g for @$help;

      $commands{$noun}{$verb} = {
         run => sub {
            my @params;

            if ($fetch) {
               my $arg = shift;
               my $obj = db($model)->find_maybe($arg);

               if ($fetch eq 'maybe') {
                  if ($obj) {
                     push @params, $obj
                  }
                  else {
                     unshift @_, $arg if defined $arg;
                  }
               }
               else {
                  abort qq{@{[ uc $model ]} not input} if !defined $arg;

                  if ($fetch eq 'all' and $arg eq 'all') {
                     push @params, db($model);
                  }
                  else {
                     abort qq{No @{[ lc $model ]} found for id "$arg"} if !$obj;

                     push @params, $fetch eq 'all'
                        ? db($model)->search({ id => $obj->id })
                        : $obj;
                  }
               }
            }

            for my $opt (@opts) {
               my $param = shift // $opt->[1];
               abort qq{@{[ uc $opt->[0] ]} not input} if !defined $param;
               push @params, $param;
            }

            $sub->(@params, @_);
         },
         usage => $usage,
         help => $help,
      };
   };
}

sub run {
	my $self = shift;
   my $noun = shift // '';
   my $verb = shift // '';

   usesub __PACKAGE__;
	if (my $c = $commands{$noun}{$verb} || $commands{$verb}{$noun}) {
      $c->{run}->(@_);
   }
   else {
      help();
   }
}

sub abort {
   say STDERR @_ and exit(1);
}

sub config {
	require WriteOff;
	return WriteOff->config;
}

sub db {
	if (my $rs = shift) {
		return schema()->resultset($rs);
	}
	else {
		return schema();
	}
}

sub dbh {
	require DBI;
	return DBI->connect('dbi:SQLite:data/WriteOff.db','','');
}

sub help {
   select STDERR;
   print <<"EOF";
usage:
   $0 COMMAND [ARGUMENTS]

available commands:
EOF

   my $s = q{ } x 3;
   for my $noun (sort keys %commands) {
      for my $verb (sort keys %{$commands{$noun}}) {
         my $c = $commands{$noun}{$verb};
         say $s . $c->{usage};
         say wrap($s x 2, $s x 2, $_), "\n" for @{ $c->{help} };
      }
   }

   print <<"EOF";
example:
   # Score pic entries in event 103 and don't apply decay
   $0 event score 103 pic
EOF

   exit(1);
}

sub schema {
	state $schema;
	return $schema if defined $schema;

	require WriteOff::Schema;
	$schema = WriteOff::Schema->connect('dbi:SQLite:data/WriteOff.db','','', {
		sqlite_unicode => 1,
		on_connect_do => q{PRAGMA foreign_keys = ON},
	});

	$schema->storage->dbh->sqlite_enable_load_extension(1);
	$schema->storage->dbh->sqlite_load_extension('./bin/libsqlitefunctions.so');
	$schema;
}

1;
