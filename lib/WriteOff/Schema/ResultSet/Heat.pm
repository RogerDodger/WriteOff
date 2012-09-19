package WriteOff::Schema::ResultSet::Heat;

use strict;
use base 'WriteOff::Schema::ResultSet';
use constant {
	CLEAN_TIMER => 60, #minutes
};

sub get_or_new_heat {
	my ($self, $event, $ip) = @_;
	
	my $heats = $event->heats->search({ ip => $ip });
	return $heats->first if $heats->count;
	
	my $n = $event->prompts->count;
	return 0 if $n < 2;
	
	my $rand = sub { int rand $n };
	
	my ($left, $right) = map { $rand->() } 0..1;
	$left = $rand->() while $right == $left;
	
	my @prompts = $event->prompts;
	
	my $id;
	do { $id = int rand(4_294_967_295) } while ( $self->find($id) );
	
	return $self->create({
		id       => $id,
		left     => $prompts[$left]->id,
		right    => $prompts[$right]->id,
		event_id => $event->id,
		ip       => $ip,
	});
}

sub clean_old_entries {
	my($self) = @_;
	
	$self->created_before( DateTime->now->subtract( minutes => CLEAN_TIMER ) )
		->delete_all;
}

1;
