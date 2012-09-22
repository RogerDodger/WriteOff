use utf8;
package WriteOff::Schema::Result::Heat;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

WriteOff::Schema::Result::Heat

=cut

use strict;
use warnings;

use Moose;
use MooseX::NonMoose;
use MooseX::MarkAsMethods autoclean => 1;
extends 'DBIx::Class::Core';

=head1 COMPONENTS LOADED

=over 4

=item * L<DBIx::Class::InflateColumn::DateTime>

=item * L<DBIx::Class::TimeStamp>

=item * L<DBIx::Class::PassphraseColumn>

=item * L<DBIx::Class::InflateColumn::Serializer>

=back

=cut

__PACKAGE__->load_components(
  "InflateColumn::DateTime",
  "TimeStamp",
  "PassphraseColumn",
  "InflateColumn::Serializer",
);

=head1 TABLE: C<heats>

=cut

__PACKAGE__->table("heats");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 left

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 right

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 ip

  data_type: 'text'
  is_nullable: 1

=head2 created

  data_type: 'timestamp'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "left",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "right",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "ip",
  { data_type => "text", is_nullable => 1 },
  "created",
  { data_type => "timestamp", is_nullable => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

=head1 RELATIONS

=head2 left

Type: belongs_to

Related object: L<WriteOff::Schema::Result::Prompt>

=cut

__PACKAGE__->belongs_to(
  "left",
  "WriteOff::Schema::Result::Prompt",
  { id => "left" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);

=head2 right

Type: belongs_to

Related object: L<WriteOff::Schema::Result::Prompt>

=cut

__PACKAGE__->belongs_to(
  "right",
  "WriteOff::Schema::Result::Prompt",
  { id => "right" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);


# Created by DBIx::Class::Schema::Loader v0.07025 @ 2012-09-22 00:43:02
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:FoWXY5vDHd6a+ya/pG8MHA
use constant {
	ELO_K       => 32,
	ELO_BETA    => 400,
};

# Need to define another belongs_to with one of the prompt tables, as joins
# throw exceptions with "left" and "right" (since they're reserved words in SQL)
__PACKAGE__->belongs_to(
  "prompt",
  "WriteOff::Schema::Result::Prompt",
  { id => "left" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);

__PACKAGE__->add_columns(
	created => {data_type => 'timestamp', set_on_create => 1},
);

sub do_heat {
	my ($row, $event, $ip, $result) = @_;
	#$result = { left => 1, tie => 0.5, right => 0 };
	
	return 0 unless 
		defined $result && 
		$row->ip eq $ip && 
		$row->left->event_id == $event->id;
	
	my ($a, $b) = ($row->left, $row->right);
	
	my $R_a = $a->rating;
	my $R_b = $b->rating;
	
	my $E_a = 1 / ( 1 + 10**( ($R_b - $R_a) / ELO_BETA ) );
	my $E_b = 1 / ( 1 + 10**( ($R_a - $R_b) / ELO_BETA ) );
	
	$a->update({ rating => $R_a + ELO_K * ( $result - $E_a ) });
	$b->update({ rating => $R_b + ELO_K * ( abs($result - 1) - $E_b ) });
	
	$row->delete;
	
	0;
}

# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
