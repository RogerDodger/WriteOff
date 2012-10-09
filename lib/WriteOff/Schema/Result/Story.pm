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

=item * L<DBIx::Class::InflateColumn::Serializer>

=back

=cut

__PACKAGE__->load_components(
  "InflateColumn::DateTime",
  "TimeStamp",
  "PassphraseColumn",
  "InflateColumn::Serializer",
);

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
  is_nullable: 0

=head2 user_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

=head2 ip

  data_type: 'text'
  is_nullable: 1

=head2 title

  data_type: 'text'
  is_nullable: 0

=head2 author

  data_type: 'text'
  default_value: 'Anonymous'
  is_nullable: 0

=head2 website

  data_type: 'text'
  is_nullable: 1

=head2 contents

  data_type: 'text'
  is_nullable: 0

=head2 wordcount

  data_type: 'integer'
  is_nullable: 0

=head2 seed

  data_type: 'real'
  is_nullable: 1

=head2 views

  data_type: 'integer'
  default_value: 0
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
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "user_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "ip",
  { data_type => "text", is_nullable => 1 },
  "title",
  { data_type => "text", is_nullable => 0 },
  "author",
  { data_type => "text", default_value => "Anonymous", is_nullable => 0 },
  "website",
  { data_type => "text", is_nullable => 1 },
  "contents",
  { data_type => "text", is_nullable => 0 },
  "wordcount",
  { data_type => "integer", is_nullable => 0 },
  "seed",
  { data_type => "real", is_nullable => 1 },
  "views",
  { data_type => "integer", default_value => 0, is_nullable => 1 },
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
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
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


# Created by DBIx::Class::Schema::Loader v0.07025 @ 2012-09-18 11:33:41
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:a1TFfpSpKNWXjdugxahEmg

__PACKAGE__->add_columns(
	created => {data_type => 'timestamp', set_on_create => 1},
	updated => {data_type => 'timestamp', set_on_create => 1, set_on_update => 1},
);

__PACKAGE__->mk_group_accessors( 
	column => 'prelim_score',
	column => 'public_score', 
	column => 'private_score',
);

sub pos {
	return shift->{__pos} // 0;
}

sub pos_low {
	return shift->{__pos_low} // 0;
}

sub artist {
	return shift->author;
}

sub stdev {
	my $self = shift;
	
	return $self->{__stdev};
}

use overload "==" => '_compare_scores',
	fallback => 1;

sub _compare_scores {
	my( $left, $right ) = @_;
	
	#Scores could be uninit, so perl will complain
	no warnings;
	
	return 0 unless $left->private_score == $right->private_score;
	return 0 unless $left->public_score == $right->public_score;
	1;
}

sub is_manipulable_by {
	my $self = shift;
	my $user = $self->result_source->schema->resultset('User')->resolve(shift)
		or return 0;
	
	return 1 if $user->is_admin;
	return 1 if $self->event->is_organised_by( $user );
	return 1 if $self->user_id == $user->id && $self->event->fic_subs_allowed;
	
	0;
}

sub id_uri {
	my $self = shift;
	
	my $desc = $self->title;
	
	for ( $desc ) {
		s/[^\w\d\s\-]//g;
		s/[\s\-]+/-/g;
	}
	
	return $self->id . '-' . $desc;
}

# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
