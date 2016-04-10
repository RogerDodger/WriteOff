package WriteOff::Schema::ResultSet::Event;

use strict;
use base 'WriteOff::Schema::ResultSet';
use Carp ();
use WriteOff::Util qw/LEEWAY/;

sub active {
	my $self = shift;
	return $self->search({},
		{
			order_by => { -desc => 'created' },
			rows => 5,
		},
	);
}

sub create_from_format {
	my ($self, $t0, $format, $genre, $organisers) = @_;
	my $schema = $self->result_source->schema;

	UNIVERSAL::isa($_->[0], $_->[1]) or Carp::croak "$_->[0] not a $_->[1]" for (
		[$t0, 'DateTime'],
		[$format, 'WriteOff::Schema::Result::Format'],
		[$genre, 'WriteOff::Schema::Result::Genre'],
	);

	my $event = $self->create({
		format_id => $format->id,
		genre_id => $genre->id,
		wc_min => $format->wc_min,
		wc_max => $format->wc_max,
		content_level => 'T',
	});

	$organisers //= $schema->resultset('User')->search({ admin => 1 });
	for my $user ($organisers->all) {
		$event->add_to_users($user, { role => 'organiser' });
	}

	my %leeway;
	for my $round ($format->rounds->ordered->all) {
		my $start = $t0->clone->add(days => $round->offset);
		my $end = $start->clone->add(days => $round->duration);

		# Rounds after a submit round start LEEWAY minutes late, since the submit
		# rounds are LEEWAY minutes longer than actual
		if ($round->action eq 'submit') {
			$leeway{$round->offset + $round->duration} = 1;
		}
		$start->add(minutes => LEEWAY) if $leeway{$round->offset};

		$event->create_related('rounds', {
			start => $start,
			end => $end,
			name => $round->name,
			mode => $round->mode,
			action => $round->action,
		});
	}

	$event->reset_jobs;

	$event;
}

sub old {
	my $self = shift;
	return $self->search({},
		{ order_by => { -desc => 'created' } },
	);
}

sub finished {
	my $self = shift;
	return $self->search(
		{ end => { '<' => $self->now } },
		{ order_by => { -asc => 'created' } }
	);
}

1;
