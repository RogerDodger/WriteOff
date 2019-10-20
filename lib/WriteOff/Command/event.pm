package WriteOff::Command::event;

use WriteOff::Command;
use Try::Tiny;
use IO::Prompt;
use HTML::Entities qw/decode_entities/;

can award =>
   sub {
      my ($e, $mode) = @_;
      my $m = WriteOff::Mode->find($mode) or abort qq{Invalid mode "$mode"};
      $e->score($m->name, decay => 0, score => 0);
   },
   which => q{
      Assigns awards to MODE entries in the event with id EVENT.
   },
   with => [
      mode => 'fic',
   ];

can calibrate =>
   sub {
      my ($e, $mode) = @_;
      my $m = WriteOff::Mode->find($mode) or abort qq{Invalid mode "$mode"};
      $e->calibrate($m, config()->{work});
   },
   which => q{
      Deletes unnecessary MODE voting rounds in event with id EVENT.
   },
   with => [
      mode => 'fic',
   ];

can reset =>
   sub {
      my ($e) = @_;
      $e->reset_jobs;
   },
   which => q{
      Resets the jobs for event with id EVENT.
   };

can score =>
   sub {
      my ($e, $mode, $decay) = @_;
      my $m = WriteOff::Mode->find($mode) or abort qq{Invalid mode "$mode"};
      $e->theorys->mode($m->name)->process if $e->guessing;
      $e->score($m->name, decay => $decay);
   },
   which => q{
      Assigns scores and awards to MODE entries in the event with id EVENT.
      Applies decay to previous events if DECAY is true.
   },
   with => [
      mode => 'fic',
      decay => 0,
   ];

1;
