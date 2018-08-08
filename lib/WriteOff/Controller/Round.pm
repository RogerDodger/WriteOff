package WriteOff::Controller::Round;
use Moose;
use namespace::autoclean;
use Try::Tiny;
use WriteOff::Mode;
use WriteOff::Util qw/maybe uniq/;

BEGIN { extends 'Catalyst::Controller' }

sub do_form :Private {
   my ($self, $c) = @_;

   my @modes = $c->req->param('mode');
   my @durs = $c->req->param('duration');
   my @ids = $c->req->param('round_id');

   if (@modes == 0 || @modes != @durs) {
      $c->yuck($c->string('noRounds'));
   }

   my @rounds;
   for my $i (0..$#modes) {
      my $mode = WriteOff::Mode->find($modes[$i] // '')
         or $c->yuck($c->string('badInput'));
      $durs[$i] =~ /(\d+)/ and $1 > 0 and $1 <= $c->config->{biz}{dur}{max}
         or $c->yuck($c->string('badInput'));

      push @rounds, {
         maybe(id => shift @ids),
         mode => $mode->name,
         duration => int $1,
      };
   }

   my %names = (
      vote => [
         [ 'final' ],
         [ 'prelim', 'final' ],
         [ 'prelim', 'semifinal', 'final' ],
      ],
      submit => {
         art => 'drawing',
         fic => 'writing',
      },
   );

   my @umodes = uniq map { $_->{mode} } @rounds;
   my %offset = map { $_ => 0 } @umodes;
   if (@umodes == 2) {
      my $rorder = $c->paramo('rorder') || 'simul';

      if ($rorder eq 'fic2pic' || $rorder eq 'pic2fic') {
         $rorder =~ s/pic/art/;
         my $fr = substr $rorder, 0, 3;
         my $to = substr $rorder, 4, 3;

         my @fr = grep { $_->{mode} eq $fr } @rounds;
         $offset{$to} = $fr[0]->{duration};
      }
   }

   for my $mode (@umodes) {
      my $offset = $offset{$mode};
      my @v = grep { $_->{mode} eq $mode } @rounds;
      my $s = shift @v;

      if ($#v > 2) {
         @v = @v[0..2];
      }

      $s->{action} = 'submit';
      $s->{name} = $names{submit}{$mode};

      for my $i (0..$#v) {
         $v[$i]->{action} = 'vote';
         $v[$i]->{name} = $names{vote}[$#v][$i];
      }

      for my $round ($s, @v) {
         $round->{offset} = $offset;
         $offset += $round->{duration};
      }
   }

   $c->stash->{rounds} = \@rounds;
}

1;
