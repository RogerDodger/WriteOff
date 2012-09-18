package WriteOff::Schema::ResultSet::LoginAttempt;

use strict;
use base 'WriteOff::Schema::ResultSet';
use constant {
	CLEAN_TIMER => 60, #minutes
};

sub clean_old_entries {
	my($self) = @_;
	
	$self->created_before( DateTime->now->subtract(minutes => CLEAN_TIMER) )
		->delete_all;
}

1;