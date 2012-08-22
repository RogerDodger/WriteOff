use utf8;
package WriteOff::Schema::Result::Story;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

WriteOff::Schema::Result::Story

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

=head1 TABLE: C<storys>

=cut

__PACKAGE__->table("storys");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 event_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

=head2 user_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

=head2 title

  data_type: 'text'
  is_nullable: 1

=head2 author

  data_type: 'text'
  is_nullable: 1

=head2 website

  data_type: 'text'
  is_nullable: 1

=head2 contents

  data_type: 'text'
  is_nullable: 1

=head2 wordcount

  data_type: 'integer'
  is_nullable: 1

=head2 created

  data_type: 'timestamp'
  is_nullable: 1

=head2 updated

  data_type: 'timestamp'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "event_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "user_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "title",
  { data_type => "text", is_nullable => 1 },
  "author",
  { data_type => "text", is_nullable => 1 },
  "website",
  { data_type => "text", is_nullable => 1 },
  "contents",
  { data_type => "text", is_nullable => 1 },
  "wordcount",
  { data_type => "integer", is_nullable => 1 },
  "created",
  { data_type => "timestamp", is_nullable => 1 },
  "updated",
  { data_type => "timestamp", is_nullable => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

=head1 UNIQUE CONSTRAINTS

=head2 C<title_unique>

=over 4

=item * L</title>

=back

=cut

__PACKAGE__->add_unique_constraint("title_unique", ["title"]);

=head1 RELATIONS

=head2 event

Type: belongs_to

Related object: L<WriteOff::Schema::Result::Event>

=cut

__PACKAGE__->belongs_to(
  "event",
  "WriteOff::Schema::Result::Event",
  { id => "event_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "CASCADE",
    on_update     => "CASCADE",
  },
);

=head2 image_stories

Type: has_many

Related object: L<WriteOff::Schema::Result::ImageStory>

=cut

__PACKAGE__->has_many(
  "image_stories",
  "WriteOff::Schema::Result::ImageStory",
  { "foreign.story_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 user

Type: belongs_to

Related object: L<WriteOff::Schema::Result::User>

=cut

__PACKAGE__->belongs_to(
  "user",
  "WriteOff::Schema::Result::User",
  { id => "user_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "CASCADE",
    on_update     => "CASCADE",
  },
);

=head2 votes

Type: has_many

Related object: L<WriteOff::Schema::Result::Vote>

=cut

__PACKAGE__->has_many(
  "votes",
  "WriteOff::Schema::Result::Vote",
  { "foreign.story_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 images

Type: many_to_many

Composing rels: L</image_stories> -> image

=cut

__PACKAGE__->many_to_many("images", "image_stories", "image");


# Created by DBIx::Class::Schema::Loader v0.07025 @ 2012-08-21 12:33:10
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:2o9hsIblmeb/ySPETWxM6g
__PACKAGE__->add_columns(
	created => {data_type => 'timestamp', set_on_create => 1},
	updated => {data_type => 'timestamp', set_on_create => 1, set_on_update => 1},
);

# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
