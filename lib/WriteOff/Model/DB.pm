package WriteOff::Model::DB;

use strict;
use base 'Catalyst::Model::DBIC::Schema';

__PACKAGE__->config(
	schema_class => 'WriteOff::Schema',

	connect_info => {
		dbh_maker => sub {
			my $dbh = DBI->connect("dbi:SQLite:data/WriteOff.db","","", {
				sqlite_unicode => 1,
				on_connect_do => q{PRAGMA foreign_keys = ON},
			});

			local $SIG{__WARN__} = sub {
				die "Failed to load `libsqlitefunctions.so`. "
				  . "Have you run `make` yet?";
			};
			$dbh->sqlite_enable_load_extension(1);
			$dbh->sqlite_load_extension('./bin/libsqlitefunctions.so');

			return $dbh;
		},
	},
);

1;
