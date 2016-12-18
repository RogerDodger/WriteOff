package Template::Provider::CHI;

use strict;
use base 'Template::Provider';
use Data::Dump;

sub _template_modified {
	my ($self, $path) = @_;

	$path = substr($path, 2);

	my $t = $self->{PARAMS}->{chi}->get_object($path);

	$t && $t->created_at;
}

sub _template_content {
	my ($self, $path) = @_;

	$path = substr($path, 2);

	my $t = $self->{PARAMS}->{chi}->get_object($path);

	my $error;
	$error = "$path: no cache hit" if !$t;

	my $val = $t && $t->value;
	my $mtime = $t && $t->created_at;

	return wantarray
		? ($val, $error, $mtime)
		: $val;
}

1;
