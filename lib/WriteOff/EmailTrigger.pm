package WriteOff::EmailTrigger;

use v5.14;
use warnings;
use Carp;
use base 'Exporter';

my @trigs;

BEGIN {
   # Order of this array is immutable -- IDs must be persistent
   @trigs = qw/EVENTCREATED SUBSOPEN VOTINGSTARTED RESULTSUP/;

   my $i = 0;
   for my $trig (@trigs) {
      $i++;
      eval qq{
         use constant _$trig => $i;
         sub $trig () {
            return __PACKAGE__->new(_$trig);
         }
      };
   }
}

my %attr = (
   _EVENTCREATED() => [ 'event-created' ],
   _SUBSOPEN() => [ 'subs-open' ],
   _VOTINGSTARTED() => [ 'voting-started' ],
   _RESULTSUP() => [ 'results-up' ],
);

our @ALL = map { eval "$_" } @trigs;
our @EXPORT_OK = ( @trigs );
our %EXPORT_TAGS = ( all => \@EXPORT_OK );

sub new {
   my ($class, $id) = @_;

   unless (exists $attr{$id}) {
      Carp::croak "Invalid trig ID: $id";
   }

   return bless \$id, $class;
}

sub find {
   my ($class, $name) = @_;

   return $name if UNIVERSAL::isa($name, __PACKAGE__);

   for my $mode (@ALL) {
      return $mode if $mode->name eq $name;
   }

   undef;
}

sub id {
   return ${ +shift };
}

sub is {
   return shift->id == shift->id;
}

sub name {
   return $attr{shift->id}->[0] =~ s/-(.)/uc $1/re;
}

sub template {
   return 'email/' . $attr{shift->id}->[0] . '.tt';
}
