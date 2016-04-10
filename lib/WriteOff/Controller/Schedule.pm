package WriteOff::Controller::Schedule;
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller' }

sub index :Path :Args(0) {
	my ($self, $c) = @_;

	$c->stash->{schedules} = $c->model('DB::Schedule')->search({}, { order_by => 'next' });
}

__PACKAGE__->meta->make_immutable;

1;
