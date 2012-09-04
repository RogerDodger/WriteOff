package WriteOff::Schema::ResultSet::Heat;

use strict;
use base 'WriteOff::Schema::ResultSet';
use constant {
	CLEAN_TIMER => 60, #minutes
};

sub new_heat {
	my ($self, $prompts) = @_;
	
	my $n = $prompts->count;
	return 0 if $n < 2;
	
	my $rand = sub { int rand $n };
	
	my ($left, $right) = map { $rand->() } 0..1;
	$left = $rand->() while $right == $left;
	
	$prompts = [$prompts->all];
	
	return $self->create({
		left  => $prompts->[$left]->id,
		right => $prompts->[$right]->id,
	});
}

sub clean_old_entries {
	my($self) = @_;
	
	$self->created_before( DateTime->now->subtract(minutes => CLEAN_TIMER) )
		->delete_all;
}

1;
