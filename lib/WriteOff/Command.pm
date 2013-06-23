package WriteOff::Command;

use strict;
use warnings;
use feature ':5.10';
use Module::Load;
use Try::Tiny;

sub import {
	my $class = shift;

	strict->import;
	warnings->import;
	feature->import(':5.10');

	no strict 'refs';
	my $caller = caller;
	push @{"${caller}::ISA"}, $class;
}

sub help {
	print <<"EOF";
usage: 
    $0 COMMAND [ARGUMENTS]

available commands:
    artist rename OLDNAME NEWNAME
        Renames an artist from OLDNAME to NEWNAME. If NEWNAME exists, merges
        OLDNAME with NEWNAME.

    backup data [FILENAME]
        Backs up the SQLite database to a timestamped file. If given, the
        database is loaded from FILENAME.

    backup logs
        Archives the logs with gunzip.    

    deploy
        Creates local config and deploys the SQLite database.

    event export EVENT STORY USERNAME
        Uploads the stories in the event with id EVENT to the Fimfiction story
        with id STORY belonging to user USERNAME.

    user add USERNAME ROLE
        Creates user USERNAME with role ROLE.

    user rename OLDNAME NEWNAME
        Renames a user from OLDNAME to NEWNAME. If NEWNAME exists, merges
        OLDNAME with NEWNAME.
EOF
	exit(1);
}

sub run {
	my ($self, $command, @args) = @_;

	if (defined $command && $command !~ /[^a-z]/ && $command !~ /^h(?:elp)?$/) {
		my $module = "${self}::${command}";
		try {
			load $module;
			try {
				$module->run(@args);
			} catch {
				print $_;
				exit(1);
			}
		} catch {
			say "Command `$command` not found.";
			exit(1);
		};
	}
	else {
		$self->help;
	}
}

sub config {
	require WriteOff;
	return WriteOff->config;
}

sub db {
	my $self = shift;

	require WriteOff::Schema;
	state $schema = WriteOff::Schema->connect('dbi:SQLite:data/WriteOff.db','','', {
		sqlite_unicode => 1,
		on_connect_do => q{PRAGMA foreign_keys = ON},
	});

	if (my $rs = shift) {
		return $schema->resultset($rs);
	}
	eles {
		return $schema;
	}
}

sub dbh {
	require DBI;
	return DBI->connect('dbi:SQLite:data/WriteOff.db','','');
}

1;
