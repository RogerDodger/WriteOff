package WriteOff::Rank;

use 5.01;
use strict;
use warnings;
use base 'Exporter';

our @EXPORT_OK = qw/twipie/;

sub uniq {
   my %uniq;
   $uniq{$_} = 1 for @_;
   keys %uniq;
}

sub flatten {
   map { ref $_ eq 'ARRAY' ? map { flatten($_) } @$_ : $_ } @_;
}

# Algorithm: Perfecting Probabilities using Test Scoring (a.k.a. TwiPie)
#
# N = (of times story N has been rated higher than another story) /
# sum over all M {(number of times story N has been compared to story M) / (N+M)}
# Initialising
sub twipie {
   my $slates = shift;

   # Initialise
   my (%scores, %p, %contr, %wins, %comps);
   my @teams = uniq flatten @$slates;

   # If there are no teams, return early to avoid divide by zero errors
   return ({}, {}) if !@teams;

   # Imaginary team, key guaranteed unique since other keys are numeric
   my $x = 'x';

   for my $n ($x, @teams) {
      $scores{$n} = 1;
      $wins{$n} = 0;
      $comps{$n} = {};
      $p{$n} = [];
      for my $m ($x, @teams) {
         $comps{$n}{$m} = 0;
      }
   }

   # Calculate wins and comps
   for my $slate (@$slates) {
      for my $i (0..$#$slate) {
         $wins{$slate->[$i]} += $#$slate - $i;
         for my $j ($i+1..$#$slate) {
            $comps{$slate->[$i]}{$slate->[$j]} += 1;
            $comps{$slate->[$j]}{$slate->[$i]} += 1;
         }
      }
   }

   # Add win and loss for each story against imaginary team
   for my $n (keys %scores) {
      next if $n eq $x;
      $wins{$n} += 1;
      $wins{$x} += 1;
      $comps{$n}{$x} = 2;
      $comps{$x}{$n} = 2;
   }

   # Calculate scores
   for (0..100) {
      my %newScores;
      for my $n (keys %scores) {
         my $sum = 0;
         for my $m (keys %scores) {
            next if $scores{$n} + $scores{$m} == 0;
            $sum += $comps{$n}{$m} / ($scores{$n} + $scores{$m});
         }
         $newScores{$n} = $wins{$n} / $sum;
      }
      %scores = %newScores;
   }

   # Calculate probability of match results for each story
   #
   # Expected outcome for N is N/(N+M)
   for my $slate (@$slates) {
      for my $i (0..$#$slate) {
         for my $j ($i+1..$#$slate) {
            my $n = $slate->[$i];
            my $m = $slate->[$j];
            push @{ $p{$n} }, abs( 1 - $scores{$n} / ($scores{$n} + $scores{$m}) );
            push @{ $p{$m} }, abs( 0 - $scores{$m} / ($scores{$n} + $scores{$m}) );
         }
      }
   }

   # Calculate controversy score, the average of outcome difference
   for my $i (keys %p) {
      my $sum = 0;
      for my $diff (@{ $p{$i} }) {
         $sum += $diff;
      }
      $contr{$i} = @{ $p{$i} } && $sum / @{ $p{$i} };
   }

   # Remove imaginary team from output
   delete $scores{$x};
   delete $contr{$x};

   return (\%scores, \%contr);
}

1;
