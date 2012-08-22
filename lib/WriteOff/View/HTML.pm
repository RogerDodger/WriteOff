package WriteOff::View::HTML;
use Moose;
use namespace::autoclean;

extends 'Catalyst::View::TT';

__PACKAGE__->config(
	WRAPPER => 'wrapper.tt',
	ENCODING => 'utf-8',
	TEMPLATE_EXTENSION => '.tt',
	render_die => 1,
);

1;
