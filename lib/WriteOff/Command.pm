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

    event reset EVENT
        Resets jobs for event with id EVENT.

    post render POST
        Renders the post with id POST, or all posts if POST eq 'all'

    user add USERNAME EMAIL [ROLE]
        Creates user USERNAME with email EMAIL and role ROLE.

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
		} catch {
			say "Command `$command` not found.";
			exit(1);
		};

		try {
			$module->run(@args);
		} catch {
			print $_;
			exit(1);
		}
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

	if (my $rs = shift) {
		return $self->schema->resultset($rs);
	}
	eles {
		return $self->schema;
	}
}

sub dbh {
	require DBI;
	return DBI->connect('dbi:SQLite:data/WriteOff.db','','');
}

sub schema {
	my $self = shift;
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
