use utf8;
package WriteOff::Schema::Result::Scoreboard;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

WriteOff::Schema::Result::Scoreboard

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

=head1 TABLE: C<scoreboard>

=cut

__PACKAGE__->table("scoreboard");

=head1 ACCESSORS

=head2 competitor

  data_type: 'text'
  is_nullable: 0

=head2 score

  data_type: 'integer'
  is_nullable: 1

=head2 awards

  data_type: 'text'
  is_nullable: 1

=head2 created

  data_type: 'timestamp'
  is_nullable: 1

=head2 updated

  data_type: 'timestamp'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "competitor",
  { data_type => "text", is_nullable => 0 },
  "score",
  { data_type => "integer", is_nullable => 1 },
  "awards",
  { data_type => "text", is_nullable => 1 },
  "created",
  { data_type => "timestamp", is_nullable => 1 },
  "updated",
  { data_type => "timestamp", is_nullable => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</competitor>

=back

=cut

__PACKAGE__->set_primary_key("competitor");


# Created by DBIx::Class::Schema::Loader v0.07025 @ 2012-09-16 17:42:20
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:OSdMxLmgnZ0c2rkQ6gkGAQ


# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
