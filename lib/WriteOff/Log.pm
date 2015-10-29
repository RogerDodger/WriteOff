package WriteOff::Log;

use Moose;
extends 'Catalyst::Log';

use File::Spec;
use POSIX ();

has path => (is => 'rw');
has timeformat => (is => 'rw', default => '%b %d %H:%M:%S');

sub _log {
	my ($self, $level, $fmt, @list) = @_;
	return if $self->abort;

	my $message = sprintf $fmt, @list;
	$message .= "\n" unless $message =~ /\n$/;
	my $timestamp = POSIX::strftime($self->timeformat, localtime);

	my $body = $self->_body // {};
	$body->{$level} //= "";
	$body->{$level} .= sprintf "%s %s", $timestamp, $message;
	$self->_body($body);
}

sub _send_to_log {
	my ($self, $body) = @_;

	for my $level (keys %$body) {
		open LOG, ">>:encoding(UTF-8)", File::Spec->catfile($self->path, "$level.log");
		print LOG $body->{$level};
		close LOG;
	}
}

no Moose;
__PACKAGE__->meta->make_immutable(inline_constructor => 0);
1;
