#!/usr/bin/env perl

#Merges user accounts into one
use 5.014;
use FindBin '$Bin';
use lib "$Bin/../lib";
use WriteOff::Schema;

my $schema = WriteOff::Schema->connect("dbi:SQLite:$Bin/../WriteOff.db");

my $main = $schema->resultset('User')->find({ username => $ARGV[0] })
	or die "Username `$ARGV[0]` does not exist";
my $dummy = shift;

printf "Merging users into `%s`\n", $main->username;

while( my $user = $schema->resultset('User')->find({ username => shift }) ) 
{
	say $user->username;

	for my $table ( qw/Artist Image Story Prompt VoteRecord/ ) 
	{
		$schema->resultset($table)
			->search({ user_id => $user->id })
			->update({ user_id => $main->id })
	}

	my $rs = $schema->resultset('UserEvent');
	for my $row ( $rs->search({ user_id => $user->id })->all )
	{
		unless( $rs->find( $main->id, $row->event_id, $row->role_id ) )
		{
			$row->update({ user_id => $main->id });
		}
	}

	$rs = $schema->resultset('UserRole');
	for my $row ( $rs->search({ user_id => $user->id })->all )
	{
		unless( $rs->find( $main->id, $row->role_id ) )
		{
			$row->update({ user_id => $main->id });
		}
	}

	$user->delete;
}