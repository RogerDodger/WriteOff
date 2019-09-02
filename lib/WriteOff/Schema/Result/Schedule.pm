use utf8;
package WriteOff::Schema::Result::Schedule;

use strict;
use warnings;
use base "WriteOff::Schema::Result";
use WriteOff::Util qw/LEEWAY/;

__PACKAGE__->table("schedules");

__PACKAGE__->add_columns(
   "id",
   { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
   "format_id",
   { data_type => "integer", is_nullable => 0 },
   "genre_id",
   { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
   "next",
   { data_type => "timestamp", is_nullable => 0 },
   "period",
   { data_type => "integer", is_nullable => 0 },
);

__PACKAGE__->set_primary_key("id");

__PACKAGE__->belongs_to("genre", "WriteOff::Schema::Result::Genre", "genre_id");
__PACKAGE__->has_many("rounds", "WriteOff::Schema::Result::ScheduleRound", "schedule_id");

sub format {
   WriteOff::Format->get(shift->format_id);
}

sub duration {
   shift->rounds
      ->search({}, {
         'select'   => [ \"duration + offset" ],
         'as'       => [ 'ttl' ],
      })
      ->get_column('ttl')
      ->max;
}

sub timeline {
   my $self = shift;
   my (@timeline, %leeway);

   for my $round ($self->rounds->ordered->all) {
      my $start = $self->next->clone->add(days => $round->offset);
      my $end = $start->clone->add(days => $round->duration);

      if ($round->mode eq 'submit') {
         $leeway{$round->offset + $round->duration} = 1;
      }
      $start->add(minutes => LEEWAY) if $leeway{$round->offset};

      push @timeline, {
         name => $round->name,
         mode => $round->mode,
         action => $round->action,
         start => $start->iso8601,
         end => $end->iso8601,
      };
   }

   \@timeline;
}

sub rorder {
   my $self = shift;
   $self->{__rorder} //= WriteOff::Util::rorder($self->rounds_rs);
}

1;
