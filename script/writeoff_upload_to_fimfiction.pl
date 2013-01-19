#!/usr/bin/env perl

use 5.014;
use FindBin '$Bin';
use lib "$Bin/../lib";
use lib "/home/cameron/WWW-Fimfiction/lib";
use WriteOff::Schema;
use Getopt::Long;
use IO::Prompt;
use WWW::Fimfiction;

my $schema = WriteOff::Schema->connect("dbi:SQLite:$Bin/../WriteOff.db",'','', { sqlite_unicode => 1 });

my( $eid, $username, $sid );
GetOptions( "event=i" => \$eid, "username=s" => \$username, "story=i" => \$sid );

my $event = $schema->resultset('Event')->find($eid) or die "Bad event ID";
                         $event->fic_gallery_opened or die "The fic gallery isn't open yet.";

my $password = prompt('Password: ', -e => '*');

my $ua = WWW::Fimfiction->new;

$ua->login($username, $password);

my $story = $ua->get_story($sid);

if( $story->{author}{name} ne $username ) {
	die "Username does not match given story author's name";
}

# Delete old chapters to make sure we don't end up with an inordinate number of dupes
for my $chapter ( @{ $story->{chapters} } ) {
	$ua->delete_chapter($chapter->{id});
	say $chapter->{title};
}

# Upload stories
for my $story ( $event->public_story_candidates ) {
	$ua->publish_chapter( $ua->add_chapter($sid, $story->title, $story->contents) );
	say $story->title;
}

$ua->publish_chapter( $ua->add_chapter($sid, 'VOTING') );

for my $story ( $event->public_story_noncandidates ) {
	$ua->publish_chapter( $ua->add_chapter($sid, $story->title, $story->contents) );
	say $story->title;
}