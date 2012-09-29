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

=head2 custom_rules

  data_type: 'text'
  is_nullable: 1

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
  "custom_rules",
  { data_type => "text", is_nullable => 1 },
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


# Created by DBIx::Class::Schema::Loader v0.07025 @ 2012-09-29 10:12:03
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:Nq0gy5gD1P33y9DqjwSpWA

__PACKAGE__->many_to_many( users => 'user_events', 'user' );

__PACKAGE__->add_columns(
	created => {data_type => 'timestamp', set_on_create => 1},
);

use constant LEEWAY => 5;

sub now_dt {
	return shift->result_source->resultset->now_dt;
}

my %levels = (
	E => 0,
	T => 1,
	M => 2,
);

sub content_level {
	my $self = shift;
	
	return $self->set_content_level(@_) if @_;
	
	return 'M' if $self->rule_set & 2;
	return 'T' if $self->rule_set & 1;
	return 'E';
}

sub set_content_level {
	my ( $self, $rating ) = @_;
	
	$self->update({ rule_set =>
		($self->rule_set & ~3) + 
		$levels{$rating} // 0 
	});
}

sub id_uri {
	my $self = shift;
	
	my $desc = $self->prompt;
	
	for ( $desc ) {
		s/[^a-zA-Z\s\-]//g;
		s/[\s\-]+/-/g;
	}
	
	return $self->id . '-' . $desc;
}


sub organisers {
	my $self = shift;
	
	return $self->users->search({ role => 'organiser' });
}

sub judges {
	my $self = shift;
	
	return $self->users->search({ role => 'judge' });
}

sub is_organised_by {
	my $self = shift;
	my $user = $self->result_source->schema->resultset('User')
		->resolve(shift) or return 0;
	
	return 1 if grep { $_->id == $user->id } $self->organisers;
	return 1 if $user->is_admin;
	
	0;
}

sub public_story_candidates {
	my( $self, $user ) = @_;
	
	my $rs = $self->storys->seed_order;
	
	if( $user ) {
		$user = $self->result_source->schema->resultset('User')->resolve($user);
		$rs = $rs->search({ user_id => { '!=' => $user ? $user->id : undef } });
	}
	
	return $rs;
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

sub is_ended {
	my $row = shift;
	
	return $row->check_datetimes_ascend( $row->end, $row->now_dt );
}

sub check_datetimes_ascend {
	my $row = shift;
	
	return 1 if join('', @_) eq join('', sort @_);
	0;
}

# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
