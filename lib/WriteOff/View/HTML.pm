package WriteOff::View::HTML;
use Moose;
use namespace::autoclean;
use Template::Stash;

extends 'Catalyst::View::TT';


__PACKAGE__->config(
	WRAPPER            => 'wrapper.tt',
	ENCODING           => 'utf-8',
	TEMPLATE_EXTENSION => '.tt',
	TIMER              => 1,
	expose_methods     => [ qw/format_dt/ ],
	render_die         => 1,
);

$Template::Stash::SCALAR_OPS->{ minus } = sub { return $_[0] - $_[1] };

sub format_dt {
	my( $self, $c, $dt, $fmt ) = @_;
	
	return '' unless eval { $dt->isa('DateTime') };
	
	$dt->set_time_zone( $c->user ? $c->user->get('timezone') : 'UTC' );
	
	$fmt //= '%a, %d %b %Y %T %Z';
	
	return $dt->strftime($fmt);
}

1;
