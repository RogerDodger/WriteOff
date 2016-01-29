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

sub fic {
	shift->search({ type => 'fic' });
}

sub finished {
	my $self = shift;
	$self->search({ end => { '<' => $self->now }});
}

sub ordered {
	shift->order_by('start');
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
	shift->search({ type => 'vote' });
}

sub writing {
	shift->search({ name => 'writing' });
}

1;
