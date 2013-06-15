package WriteOff::Schema::Result;

use base 'DBIx::Class::Core';
require DateTime;

__PACKAGE__->load_components(qw/InflateColumn::DateTime DynamicDefault/);

sub add_columns {
	my $self = shift;
	my %cols = @_;

	for my $col (keys %cols) {
		my $info = $cols{$col};

		next unless $info->{data_type} eq 'timestamp';

		if ($col eq 'created') {
			$info->{dynamic_default_on_create} = 'get_timestamp';
		}
		elsif ($col eq 'updated') {
			$info->{dynamic_default_on_create} = 'get_timestamp';
			$info->{dynamic_default_on_update} = 'get_timestamp';
		}
	}

	$self->next::method(@_);
}

sub get_timestamp {
	return DateTime->now;
}
