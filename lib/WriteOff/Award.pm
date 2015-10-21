package WriteOff::Award;

use v5.14;
use warnings;
use Carp;
use Exporter;

my @awards;

BEGIN {
	# Order of this array is immutable -- IDs must be persistent
	@awards = qw/GOLD SILVER BRONZE CONFETTI SPOON RIBBON SLEUTH MASK/;

	my $i = 0;
	for my $award (@awards) {
		$i++;
		eval qq{
			use constant _$award => $i;
			sub $award () {
				return __PACKAGE__->new(_$award);
			}
		};
	}
}

our @ISA = qw/Exporter/;
our @EXPORT_OK = ( @awards, qw/all_awards sort_awards/ );
our %EXPORT_TAGS = ( awards => \@awards, all => \@EXPORT_OK );

my %attr = (
	_GOLD()     => [ 1, 'gold',     'Gold medal',   'First place'        ],
	_SILVER()   => [ 2, 'silver',   'Silver medal', 'Second place'       ],
	_BRONZE()   => [ 3, 'bronze',   'Bronze medal', 'Third place'        ],
	_CONFETTI() => [ 4, 'confetti', 'Confetti',     'Most controversial' ],
	_SPOON()    => [ 5, 'spoon',    'Wooden spoon', 'Last place'         ],
	_RIBBON()   => [ 6, 'ribbon',   'Ribbon',       'Consolation prize'  ],
	_SLEUTH()   => [ 7, 'sleuth',   'Sleuth',       'Best guesser'       ],
	_MASK()     => [ 8, 'mask',     'Mask',         'Avoided detection'  ],
);

my @order = sort { $attr{$a}->[0] <=> $attr{$b}->[0] } keys %attr;

sub new {
	my ($class, $id) = @_;

	unless (exists $attr{$id}) {
		Carp::croak "Invalid award ID: $id";
	}

	return bless \$id, $class;
}

sub id {
	return ${ +shift };
}

sub is {
	return shift->id == shift->id;
}

sub alt {
	return $attr{shift->id}->[2];
}

sub html {
	my $self = shift;
	return sprintf q{<img class="Award" src="%s" alt="%s" title="%s">},
		$self->src, $self->alt, $self->title;
}

sub name {
	return $attr{shift->id}->[1];
}

sub order {
	return $attr{shift->id}->[0];
}

sub src {
	return '/static/images/awards/' . shift->name . '.png';
}

sub title {
	return $attr{shift->id}->[3];
}

*type = \&name;

sub all_awards {
	map { __PACKAGE__->new($_) } @order;
}

sub sort_awards {
	my %bin;
	for my $award (@_) {
		$bin{$award->id}++;
	}

	my @awards = map { __PACKAGE__->new($_) }
	               map { ($_) x ($bin{$_} // 0) }
	                  @order;
	return @awards;
}
