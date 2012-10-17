use utf8;
package WriteOff::Schema::Result::VoteRecord;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

WriteOff::Schema::Result::VoteRecord

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

=head1 TABLE: C<vote_records>

=cut

__PACKAGE__->table("vote_records");

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

=head2 round

  data_type: 'text'
  is_nullable: 0

=head2 type

  data_type: 'text'
  is_nullable: 0

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
  "round",
  { data_type => "text", is_nullable => 0 },
  "type",
  { data_type => "text", is_nullable => 0 },
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
  { "foreign.record_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07025 @ 2012-10-13 08:49:51
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:KqJkiITugLAVTb17hhC7sg
__PACKAGE__->add_columns(
	created => {data_type => 'timestamp', set_on_create => 1},
	updated => {data_type => 'timestamp', set_on_create => 1, set_on_update => 1},
);

__PACKAGE__->mk_group_accessors(
	column => 'variance',
	column => 'mean',
);

sub is_filled {
	my $self = shift;
	
	return 1 if defined $self->votes->get_column('value')->next;
	0;
}

sub is_empty {
	my $self = shift;
	
	return 1 if $self->votes->count == 0;
	0;
}

sub is_unfilled {
	my $self = shift;
	
	return 0 if $self->is_filled;
	return 0 if $self->is_empty;
	1;
}

sub stdev {
	my $self = shift;
	
	return eval { sqrt $self->variance } // $self->votes->stdev;
}

sub values {
	my $self = shift;
	
	return $self->votes->get_column('value');
}

# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
