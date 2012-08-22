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

=back

=cut

__PACKAGE__->load_components("InflateColumn::DateTime", "TimeStamp", "PassphraseColumn");

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
  is_nullable: 1

=head2 right

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

=head2 created

  data_type: 'timestamp'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "left",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "right",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
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
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "CASCADE",
    on_update     => "CASCADE",
  },
);

=head2 right

Type: belongs_to

Related object: L<WriteOff::Schema::Result::Prompt>

=cut

__PACKAGE__->belongs_to(
  "right",
  "WriteOff::Schema::Result::Prompt",
  { id => "right" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "CASCADE",
    on_update     => "CASCADE",
  },
);


# Created by DBIx::Class::Schema::Loader v0.07025 @ 2012-08-10 19:18:46
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:0z1OG6N3F11N+tj6stQxxA
__PACKAGE__->add_columns(
	created => {data_type => 'timestamp', set_on_create => 1},
);

# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
