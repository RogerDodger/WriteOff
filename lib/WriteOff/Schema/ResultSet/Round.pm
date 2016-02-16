package WriteOff::Schema::ResultSet::Round;

use strict;
use warnings;
use base 'WriteOff::Schema::ResultSet';

for my $meth (qw/active fic finished ordered upcoming vote writing/) {
	eval qq{
		sub $meth\_rs { scalar shift->$meth(@_) }
	};
}

sub active {
	my ($self, %opt) = @_;
	$self->search({
		start => { '<' => $self->now },
		end => { '>' => $opt{leeway} ? $self->now_leeway : $self->now },
	});
}

sub art {
	shift->search({ mode => 'art' });
}

sub fic {
	shift->search({ mode => 'fic' });
}

sub finished {
	my $self = shift;
	$self->search({ end => { '<' => $self->now }});
}

sub ordered {
	shift->order_by('start');
}

sub submit {
	shift->search({ action => 'submit' });
}

sub started {
	my $self = shift;
	$self->search({ start => { '<' => $self->now }});
}

sub upcoming {
	my $self = shift;
	$self->search({ end => { '>' => $self->now }});
}

sub vote {
	shift->search({ action => 'vote' });
}

sub writing {
	Carp::croak "Deprecated method 'writing' called";
}

1;
