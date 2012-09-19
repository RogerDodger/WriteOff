use utf8;
package WriteOff::Schema::Result::Event;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

WriteOff::Schema::Result::Event

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

=head1 TABLE: C<events>

=cut

__PACKAGE__->table("events");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 prompt

  data_type: 'text'
  default_value: 'TBD'
  is_nullable: 0

=head2 blurb

  data_type: 'text'
  is_nullable: 1

=head2 wc_min

  data_type: 'integer'
  is_nullable: 0

=head2 wc_max

  data_type: 'integer'
  is_nullable: 0

=head2 rule_set

  data_type: 'integer'
  default_value: 1
  is_nullable: 0

=head2 start

  data_type: 'timestamp'
  is_nullable: 0

=head2 prompt_voting

  data_type: 'timestamp'
  is_nullable: 0

=head2 art

  data_type: 'timestamp'
  is_nullable: 1

=head2 art_end

  data_type: 'timestamp'
  is_nullable: 1

=head2 fic

  data_type: 'timestamp'
  is_nullable: 0

=head2 fic_end

  data_type: 'timestamp'
  is_nullable: 0

=head2 prelim

  data_type: 'timestamp'
  is_nullable: 1

=head2 public

  data_type: 'timestamp'
  is_nullable: 0

=head2 private

  data_type: 'timestamp'
  is_nullable: 1

=head2 end

  data_type: 'timestamp'
  is_nullable: 0

=head2 created

  data_type: 'timestamp'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "prompt",
  { data_type => "text", default_value => "TBD", is_nullable => 0 },
  "blurb",
  { data_type => "text", is_nullable => 1 },
  "wc_min",
  { data_type => "integer", is_nullable => 0 },
  "wc_max",
  { data_type => "integer", is_nullable => 0 },
  "rule_set",
  { data_type => "integer", default_value => 1, is_nullable => 0 },
  "start",
  { data_type => "timestamp", is_nullable => 0 },
  "prompt_voting",
  { data_type => "timestamp", is_nullable => 0 },
  "art",
  { data_type => "timestamp", is_nullable => 1 },
  "art_end",
  { data_type => "timestamp", is_nullable => 1 },
  "fic",
  { data_type => "timestamp", is_nullable => 0 },
  "fic_end",
  { data_type => "timestamp", is_nullable => 0 },
  "prelim",
  { data_type => "timestamp", is_nullable => 1 },
  "public",
  { data_type => "timestamp", is_nullable => 0 },
  "private",
  { data_type => "timestamp", is_nullable => 1 },
  "end",
  { data_type => "timestamp", is_nullable => 0 },
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

=head2 heats

Type: has_many

Related object: L<WriteOff::Schema::Result::Heat>

=cut

__PACKAGE__->has_many(
  "heats",
  "WriteOff::Schema::Result::Heat",
  { "foreign.event_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 images

Type: has_many

Related object: L<WriteOff::Schema::Result::Image>

=cut

__PACKAGE__->has_many(
  "images",
  "WriteOff::Schema::Result::Image",
  { "foreign.event_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 prompts

Type: has_many

Related object: L<WriteOff::Schema::Result::Prompt>

=cut

__PACKAGE__->has_many(
  "prompts",
  "WriteOff::Schema::Result::Prompt",
  { "foreign.event_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 storys

Type: has_many

Related object: L<WriteOff::Schema::Result::Story>

=cut

__PACKAGE__->has_many(
  "storys",
  "WriteOff::Schema::Result::Story",
  { "foreign.event_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 user_events

Type: has_many

Related object: L<WriteOff::Schema::Result::UserEvent>

=cut

__PACKAGE__->has_many(
  "user_events",
  "WriteOff::Schema::Result::UserEvent",
  { "foreign.event_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 vote_records

Type: has_many

Related object: L<WriteOff::Schema::Result::VoteRecord>

=cut

__PACKAGE__->has_many(
  "vote_records",
  "WriteOff::Schema::Result::VoteRecord",
  { "foreign.event_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07025 @ 2012-09-19 14:33:15
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:FfY9FxzJmXNr1CV1mwGIMA

use constant LEEWAY => 5;

__PACKAGE__->add_columns(
	created => {data_type => 'timestamp', set_on_create => 1},
);

sub id_uri {
	my $self = shift;
	
	my $desc = $self->prompt;
	
	for ( $desc ) {
		s/[^a-zA-Z\s\-]//g;
		s/[\s\-]+/-/g;
	}
	
	return $self->id . '-' . $desc;
}

sub first_round {
	my $row = shift;
	return $row->art || $row->fic;
}

sub now_dt {
	return shift->result_source->resultset->now_dt;
}

sub prompt_subs_allowed {
	my $row = shift;
	
	return $row->check_datetimes_ascend 
	( $row->start, $row->now_dt, $row->prompt_voting);
}

sub prompt_votes_allowed {
	my $row = shift;
	
	return $row->check_datetimes_ascend 
	( $row->prompt_voting, $row->now_dt, $row->art || $row->fic );
}

sub art_subs_allowed {
	my $row = shift;
	
	return $row->check_datetimes_ascend 
	( $row->art, $row->now_dt, $row->art_end->clone->add({ minutes => LEEWAY }) );
}

sub fic_subs_allowed {
	my $row = shift;
		
	return $row->check_datetimes_ascend
	( $row->fic, $row->now_dt, $row->fic_end->clone->add({ minutes => LEEWAY }) );
}

sub fic_gallery_opened {
	my $row = shift;
	
	return $row->check_datetimes_ascend( $row->public, $row->now_dt );
}

sub public_votes_allowed {
	my $row = shift;
	
	return $row->check_datetimes_ascend
	( $row->public, $row->now_dt, $row->private || $row->end );
}

sub check_datetimes_ascend {
	my $row = shift;
	
	return 1 if join('', @_) eq join('', sort @_);
	0;
}

# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
