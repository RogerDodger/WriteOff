package WriteOff::DateTime;

require DateTime;
require DateTime::Format::Human::Duration;
require DateTime::Format::RFC3339;
use 5.014;

sub DateTime::rfc2822 {
	my $self = shift;
	return $self->strftime('%a, %d %b %Y %T %Z');
}

sub DateTime::delta {
	my $self  = shift;
	my $other = shift || __PACKAGE__->now;
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

	return sprintf '<time class="delta" title="%s" datetime="%sZ">%s</time>',
		$self->rfc2822,
		$self->iso8601,
		$self->delta;
}

sub DateTime::date_html {
	my $self = shift;

	return sprintf '<time class="date" title="%s" datetime="%sZ">%s</time>',
		$self->rfc2822,
		$self->iso8601,
		$self->strftime('%d %b %Y');
}

sub DateTime::datetime_html {
	my $self = shift;

	return sprintf '<time class="datetime" title="%s" datetime="%sZ">%s</time>',
		$self->rfc2822,
		$self->iso8601,
		$self->strftime('%d %b %Y %T %z');
}

sub now {
	if (defined(my $t = $ENV{WRITEOFF_DATETIME})) {
		return DateTime::Format::RFC3339->parse_datetime($t);
	}
	return DateTime->now;
}

sub timezones {
	# The grep matches only location-based timezones, e.g.,
	# "Australia/Adelaide", removing things like "EST" and "CET"
	return qw/UTC/, grep { m{/} } DateTime::TimeZone->all_names;
}

1;
