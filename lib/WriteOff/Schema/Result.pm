package WriteOff::Schema::Result;

use base 'DBIx::Class::Core';
require DateTime;

__PACKAGE__->load_components(qw/InflateColumn::DateTime DynamicDefault/);

sub add_columns {
   my $self = shift;
   my %cols = @_;

   for my $col (keys %cols) {
      my $info = $cols{$col};

      if ($info->{data_type} eq 'timestamp') {
         $info->{dynamic_default_on_create} = 'get_timestamp';
         if ($col eq 'updated') {
            $info->{dynamic_default_on_update} = 'get_timestamp';
         }
      }
   }

   $self->next::method(@_);
}

sub get_timestamp {
   return DateTime->now;
}

sub parse_datetime {
   shift->result_source->schema->storage->datetime_parser->parse_datetime(shift);
}
