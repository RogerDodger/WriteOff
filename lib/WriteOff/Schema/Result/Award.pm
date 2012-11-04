use utf8;
package WriteOff::Schema::Result::Award;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

WriteOff::Schema::Result::Award

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

=head1 TABLE: C<awards>

=cut

__PACKAGE__->table("awards");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 name

  data_type: 'text'
  is_nullable: 1

=head2 sort_rank

  data_type: 'integer'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "name",
  { data_type => "text", is_nullable => 1 },
  "sort_rank",
  { data_type => "integer", is_nullable => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

=head1 UNIQUE CONSTRAINTS

=head2 C<name_unique>

=over 4

=item * L</name>

=back

=cut

__PACKAGE__->add_unique_constraint("name_unique", ["name"]);

=head1 RELATIONS

=head2 artist_awards

Type: has_many

Related object: L<WriteOff::Schema::Result::ArtistAward>

=cut

__PACKAGE__->has_many(
  "artist_awards",
  "WriteOff::Schema::Result::ArtistAward",
  { "foreign.award_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07025 @ 2012-10-30 10:19:57
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:r73w43J0FzCA3TY/VKrf5w

sub src {
	return '/static/images/awards/' . shift->name . '.png';
}

sub type {
	(my $type = shift->name) =~ s/x\d+$//;
	
	return $type;
}

my %alt = (
	gold     => 'Gold medal',
	silver   => 'Silver medal',
	bronze   => 'Bronze medal',
	ribbon   => 'Participation ribbon',
	confetti => 'Most controversial',
	spoon    => 'Wooden spoon',
);

sub alt {
	return $alt{ shift->type } // 'Unknown';
}

# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
