package WriteOff::Log;

use Moose;
extends 'Catalyst::Log';

use File::Spec;
use POSIX ();

has path => (is => 'rw');
has timeformat => (is => 'rw', default => '%b %d %H:%M:%S');

sub _log {
	my( $self, $level, $message ) = @_;
	return if $self->abort;

	$message .= "\n" unless $message =~ /\n$/;
	my $timestamp = POSIX::strftime($self->timeformat, localtime);

	open LOG, ">>:encoding(UTF-8)", File::Spec->catfile($self->path, "$level.log");
	printf LOG "%s %s", $timestamp, $message;
	close LOG;
}

sub _flush {
	my $self = shift;
	$self->abort(0);
}

no Moose;
__PACKAGE__->meta->make_immutable(inline_constructor => 0);
1;
