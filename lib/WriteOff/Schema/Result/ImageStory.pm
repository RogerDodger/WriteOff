use utf8;
package WriteOff::Schema::Result::ImageStory;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

WriteOff::Schema::Result::ImageStory

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

=head1 TABLE: C<image_story>

=cut

__PACKAGE__->table("image_story");

=head1 ACCESSORS

=head2 image_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 story_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "image_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "story_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
);

=head1 PRIMARY KEY

=over 4

=item * L</image_id>

=item * L</story_id>

=back

=cut

__PACKAGE__->set_primary_key("image_id", "story_id");

=head1 RELATIONS

=head2 image

Type: belongs_to

Related object: L<WriteOff::Schema::Result::Image>

=cut

__PACKAGE__->belongs_to(
  "image",
  "WriteOff::Schema::Result::Image",
  { id => "image_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);

=head2 story

Type: belongs_to

Related object: L<WriteOff::Schema::Result::Story>

=cut

__PACKAGE__->belongs_to(
  "story",
  "WriteOff::Schema::Result::Story",
  { id => "story_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);


# Created by DBIx::Class::Schema::Loader v0.07025 @ 2012-12-11 13:01:51
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:FCA8F5hLtIJkBGJYrD8XuQ


# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
