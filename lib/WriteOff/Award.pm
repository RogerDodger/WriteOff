package WriteOff::Award;

use v5.14;
use warnings;
use Carp;
use Exporter;

my @awards;

BEGIN {
   # Order of this array is immutable -- IDs must be persistent
   @awards = qw/GOLD SILVER BRONZE CONFETTI SPOON RIBBON SLEUTH MASK MORTARBOARD LIGHTBULB/;

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
   _GOLD()        => [ 1, 'gold',          'Gold medal',    'First place', 1 ],
   _SILVER()      => [ 2, 'silver',        'Silver medal',  'Second place', 1 ],
   _BRONZE()      => [ 3, 'bronze',        'Bronze medal',  'Third place', 1 ],
   _CONFETTI()    => [ 12, 'confetti',     'Confetti',      'Most controversial', 1 ],
   _SPOON()       => [ 13, 'spoon',        'Wooden spoon',  'Last place', 1 ],
   _LIGHTBULB()   => [ 14, 'lightbulb',    'Lightbulb',     'Most inspiring', 1 ],
   _MASK()        => [ 15, 'mask',         'Mask',          'Avoided detection', 1 ],
   _SLEUTH()      => [ 21, 'sleuth',       'Sleuth',        'Best guesser', 1 ],
   _MORTARBOARD() => [ 100, 'mortarboard', 'Mortarboard',   'Writeoff graduate', 0 ],
   _RIBBON()      => [ 101, 'ribbon',      'Ribbon',        'Participation',  1 ],
);

my %color = (
   _GOLD()        => [ "#88b877" ],
   _SILVER()      => [ "#db9a9d" ],
   _BRONZE()      => [ "#86afd6" ],
   _CONFETTI()    => [ "#b6a2d6" ],
   _SPOON()       => [ "#b6a2d6" ],
   _LIGHTBULB()   => [ "#b6a2d6" ],
   _MASK()        => [ "#b6a2d6" ],
   _SLEUTH()      => [ "#b6a2d6" ],
   _MORTARBOARD() => [ "#b6a2d6" ],
   _RIBBON()      => [ "#7db6ae" ],
);

my @order = sort { $attr{$a}->[0] <=> $attr{$b}->[0] } keys %attr;
our @ORDERED = map { __PACKAGE__->new($_) } @order;

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

sub color {
   return $color{shift->id}->[0];
}

sub html {
   my $self = shift;
   return sprintf q{<img class="Award %s" src="%s" alt="%s" title="%s">},
      $self->name, $self->src, $self->alt, $self->title;
}

sub name {
   return $attr{shift->id}->[1];
}

sub order {
   return $attr{shift->id}->[0];
}

sub src {
   return '/static/images/awards/' . shift->name . '.svg';
}

sub tallied {
   return $attr{shift->id}->[4];
}

sub title {
   return $attr{shift->id}->[3];
}

*type = \&name;

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
