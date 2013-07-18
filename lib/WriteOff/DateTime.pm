package WriteOff::DateTime;

require DateTime;
require DateTime::Format::Human::Duration;
use 5.014;

sub DateTime::rfc2822 {
	my $self = shift;
	return $self->strftime('%a, %d %b %Y %T %Z');
}

sub DateTime::delta {
	my $self  = shift;
	my $other = shift || DateTime->now;
	state $fmt = DateTime::Format::Human::Duration->new;

	return $fmt->format_duration_between($other, $self,
		past => '%s ago',
		future => 'in %s',
		no_time => 'just now',
		significant_units => 2,
	);
}

sub DateTime::delta_html {
	my $self = shift;

	return sprintf '<time title="%s" datetime="%sZ">%s</time>',
		$self->rfc2822,
		$self->iso8601,
		$self->delta;
}

1;
