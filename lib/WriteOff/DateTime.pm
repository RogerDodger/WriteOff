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
	my $self = shift;
	my $figs = shift || 2;
	state $fmt = DateTime::Format::Human::Duration->new;

	return $fmt->format_duration_between(__PACKAGE__->now, $self,
		past => '%s ago',
		future => 'in %s',
		no_time => 'just now',
		significant_units => $figs,
	);
}

sub DateTime::delta_html {
	my ($self, $figs) = @_;

	sprintf '<time class="delta%s" title="%s" datetime="%sZ">%s</time>',
		$figs == 1 ? " short" : '',
		$self->rfc2822,
		$self->iso8601,
		$self->delta($figs);
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
