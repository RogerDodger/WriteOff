package WriteOff::Format;

use v5.14;
use warnings;
use Carp;
use Exporter;
use Scalar::Util qw/looks_like_number/;

my @formats;

BEGIN {
   # Order of this array is immutable -- IDs must be persistent
   @formats = qw/FLASHFIC MINIFIC SHORTSHORT SHORTSTORY NOVELETTE NOVELLA NOVEL/;

   my $i = 0;
   for my $format (@formats) {
      $i++;
      eval qq{
         use constant _$format => $i;
         sub $format () {
            return __PACKAGE__->new(_$format);
         }
      };
   }
}

our @ISA = qw/Exporter/;
our @EXPORT_OK = ( @formats );
our %EXPORT_TAGS = ( formats => \@formats, all => \@EXPORT_OK );

my %attr = (
   _FLASHFIC()   => [ 'flashfic', 300 ],
   _MINIFIC()    => [ 'minific', 1000 ],
   _SHORTSHORT() => [ 'shortShort', 2250 ],
   _SHORTSTORY() => [ 'shortStory', 9000 ],
   _NOVELETTE()  => [ 'novelette', 20000 ],
   _NOVELLA()    => [ 'novella', 45000 ],
   _NOVEL()      => [ 'novel', undef ],
);

our @ALL = map { eval "$_" } @formats;

sub for {
   my ($class, $wc_max) = @_;
   return unless defined $wc_max && looks_like_number $wc_max;

   state $formats = [
      sort { $a->limit <=> $b->limit }
         grep { defined $_->limit }
            map { __PACKAGE__->new($_) }
               keys %attr
   ];
   for my $format (@$formats) {
      return $format if $wc_max <= $format->limit;
   }

   return NOVEL;
}

sub get {
   my ($class, $id) = @_;

   exists $attr{$id} ? bless \$id, $class : undef;
}

sub new {
   my ($class, $id) = @_;

   unless (exists $attr{$id}) {
      Carp::croak "Invalid format ID: $id";
   }

   return bless \$id, $class;
}

sub id {
   return ${ +shift };
}

sub is {
   return shift->id == shift->id;
}

sub limit {
   return $attr{shift->id}->[1];
}

sub name {
   return $attr{shift->id}->[0];
}

*type = \&name;
