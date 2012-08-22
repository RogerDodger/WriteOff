use utf8;
package WriteOff::Schema::Result::Vote;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

WriteOff::Schema::Result::Vote

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

=head1 TABLE: C<votes>

=cut

__PACKAGE__->table("votes");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 record_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

=head2 story_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

=head2 rating

  data_type: 'integer'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "record_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "story_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "rating",
  { data_type => "integer", is_nullable => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

=head1 UNIQUE CONSTRAINTS

=head2 C<record_id_story_id_unique>

=over 4

=item * L</record_id>

=item * L</story_id>

=back

=cut

__PACKAGE__->add_unique_constraint("record_id_story_id_unique", ["record_id", "story_id"]);

=head1 RELATIONS

=head2 record

Type: belongs_to

Related object: L<WriteOff::Schema::Result::VoteRecord>

=cut

__PACKAGE__->belongs_to(
  "record",
  "WriteOff::Schema::Result::VoteRecord",
  { id => "record_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "CASCADE",
    on_update     => "CASCADE",
  },
);

=head2 story

Type: belongs_to

Related object: L<WriteOff::Schema::Result::Story>

=cut

__PACKAGE__->belongs_to(
  "story",
  "WriteOff::Schema::Result::Story",
  { id => "story_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "CASCADE",
    on_update     => "CASCADE",
  },
);


# Created by DBIx::Class::Schema::Loader v0.07025 @ 2012-08-10 19:18:46
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:H3u2glB6Yu/C37+b53yDrA


# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
