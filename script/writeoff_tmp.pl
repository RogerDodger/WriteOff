#!/usr/bin/perl

use strict;
use warnings;
use 5.014;
BEGIN { push @INC, 'lib'; }

use WriteOff::Schema;
my $schema = WriteOff::Schema->connect('dbi:SQLite:WriteOff.db');

require DateTime::Format::SQLite;

my @news;

push @news, {
	title   => 'Archive now fully populated',
	user_id => 1,
	created => DateTime::Format::SQLite->parse_datetime('2012-11-14 16:50:00'),
	updated => DateTime::Format::SQLite->parse_datetime('2012-11-14 16:50:00'),
	body    => <<NEWS,
Hey, just lettin' everyone know that the site was temporarily down while I populated the database with the old write-offs. That's right—[the archive](http://writeoff.rogerdodger.me/archive) now contains every bit of write-off history!

**Important!**
Remember that artist names are reserved to the first people who get them. The way this works is by taking the set of all artists and subtracting any attached to your user account from the set. This set contains a list of artist names that you may not submit as. Now, because the old data contains names from people who aren't registered, or names that don't quite associate with any user account, a lot of names are going to be "stuck in limbo" and unusable.

The [My Submissions](http://writeoff.rogerdodger.me/user/me) page should contain all of your submissions. If any of your stories happen to not be in that list, [let me know](http://writeoff.rogerdodger.me/contact). I've tried to associate the old stories with user accounts as best as possible, but there's a lot of them (and I'm tired).
NEWS
};

push @news, {
	title   => 'DDoS downtime',
	user_id => 1,
	created => DateTime::Format::SQLite->parse_datetime('2012-11-17 17:45:00'),
	updated => DateTime::Format::SQLite->parse_datetime('2012-11-17 17:45:00'),
	body    => <<NEWS,
MLPchan's servers experienced a DDoS over the last couple hours, which is why the site was unavailable. And the Hearth's Warming Care Package deadline is right about now. Because of work or other commitments, I understand that the last few hours may have been the only time some people may have had to submit today. As such, the deadline's been extended by 24 hours to make sure nobody missed out because of this issue.

Sorry for the inconvenience.
NEWS
};

$schema->resultset('News')->create($_) for @news;