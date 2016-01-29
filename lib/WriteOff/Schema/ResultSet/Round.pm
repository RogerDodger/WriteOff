package WriteOff::Schema::ResultSet::Round;

use strict;
use warnings;
use base 'WriteOff::Schema::ResultSet';

for my $meth (qw/active fic finished upcoming writing/) {
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

sub upcoming {
	my $self = shift;

	$self->search({ end => { '>' => $self->now }});
}

sub writing {
	my $self = shift;

	$self->search({ name => 'writing' });
}

1;
