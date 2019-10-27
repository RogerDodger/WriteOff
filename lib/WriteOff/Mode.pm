package WriteOff::Mode;

use v5.14;
use warnings;
use Carp;
use Exporter;
use overload
   '""' => \&name,
   fallback => 1;

my @modes;

BEGIN {
   # Order of this array is immutable -- IDs must be persistent
   @modes = qw/FIC PIC/;

   my $i = 0;
   for my $mode (@modes) {
      $i++;
      eval qq{
         use constant _$mode => $i;
         sub $mode () {
            return __PACKAGE__->new(_$mode);
         }
      };
   }
}

our @ISA = qw/Exporter/;
our @EXPORT_OK = ( @modes );
our %EXPORT_TAGS = ( all => \@EXPORT_OK );

my %attr = (
   _FIC() => [ 'fic', 'story_id', 'story' ],
   _PIC() => [ 'pic', 'image_id', 'image' ],
);

our @ALL = map { eval "$_" } @modes;

sub new {
   my ($class, $id) = @_;

   unless (exists $attr{$id}) {
      Carp::croak "Invalid mode ID: $id";
   }

   return bless \$id, $class;
}

sub find {
   my ($class, $name) = @_;
   return if !defined $name;
   return $name if UNIVERSAL::isa($name, __PACKAGE__);

   for my $mode (@ALL) {
      return $mode if $mode->name eq $name;
   }

   undef;
}

sub fkey {
   return $attr{shift->id}->[1];
}

sub id {
   return ${ +shift };
}

sub is {
   return shift->id == shift->id;
}

sub item {
   return $attr{shift->id}->[2];
}

sub name {
   return $attr{shift->id}->[0];
}
