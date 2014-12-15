package WriteOff::Award;

use v5.14;
use warnings;
use Carp;
use Exporter;

my @awards;

BEGIN {
	@awards = qw/GOLD SILVER BRONZE CONFETTI SPOON RIBBON SLEUTH/;

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
our @EXPORT_OK = ( @awards, qw/sort_awards/ );
our %EXPORT_TAGS = ( awards => \@awards, all => \@EXPORT_OK );

my %attr = (
	_GOLD()     => [ 'gold',     'Gold medal' ],
	_SILVER()   => [ 'silver',   'Silver medal' ],
	_BRONZE()   => [ 'bronze',   'Bronze medal' ],
	_CONFETTI() => [ 'confetti', 'Most controversial' ],
	_SPOON()    => [ 'spoon',    'Wooden spoon' ],
	_RIBBON()   => [ 'ribbon',   'Participation ribbon' ],
	_SLEUTH()   => [ 'sleuth',   'Best guesser' ],
);

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
	return $attr{shift->id}->[1];
}

sub html {
	my $self = shift;
	return sprintf q{<img src="%s" alt="%s" title="%s">},
	                 $self->src, $self->alt, $self->title;
}

sub name {
	return $attr{shift->id}->[0];
}

sub src {
	return '/static/images/awards/' . shift->name . '.png';
}

*title = \&alt;

*type = \&name;

sub sort_awards {
	state $order = [
		_GOLD, _SILVER, _BRONZE, _SLEUTH, _CONFETTI, _SPOON, _RIBBON
	];

	my %bin;
	for my $award (@_) {
		$bin{$award->id}++;
	}

	my @awards = map { WriteOff::Award->new($_) }
	               map { ($_) x ($bin{$_} // 0) }
	                  @$order;
	return @awards;
}
