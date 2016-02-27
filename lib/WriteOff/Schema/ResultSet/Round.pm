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

sub after {
	my ($self, $round) = @_;
	$self->search(
			{ start => { '>' => $self->format_datetime($round->start) } },
			{ order_by => { -asc => 'start' } }
		)->first;
}

sub art {
	shift->search({ mode => 'art' });
}

sub before {
	my ($self, $round) = @_;
	$self->search(
			{ start => { '<' => $self->format_datetime($round->start) } },
			{ order_by => { -desc => 'start' } },
		)->first;
}

sub fic {
	shift->search({ mode => 'fic' });
}

sub finished {
	my $self = shift;
	$self->search({ end => { '<' => $self->now }});
}

sub mode {
	shift->search({ mode => shift });
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
