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

my $RFC2822 = '%a, %d %b %Y %T %Z';

sub format_dt {
	my( $self, $c, $dt, $fmt ) = @_;
	
	return '' unless eval { $dt->set_time_zone('UTC')->isa('DateTime') };
	
	my $tz = $c->user ? $c->user->get('timezone') : 'UTC';
	
	return sprintf '<time title="%s" datetime="%sZ">%s</time>',
	$dt->strftime($RFC2822), 
	$dt->iso8601, 
	$dt->set_time_zone($tz)->strftime($fmt // $RFC2822);
}

1;
