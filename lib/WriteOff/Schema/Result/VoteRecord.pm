use utf8;
package WriteOff::Schema::Result::VoteRecord;

use strict;
use warnings;
use base "WriteOff::Schema::Result";

__PACKAGE__->table("vote_records");

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
	{ data_type => "text", default_value => "unknown", is_nullable => 0 },
	"filled",
	{ data_type => "bit", default_value => 0, is_nullable => 0 },
	"mean",
	{ data_type => "real", is_nullable => 1 },
	"stdev",
	{ data_type => "real", is_nullable => 1 },
	"created",
	{ data_type => "timestamp", is_nullable => 1 },
	"updated",
	{ data_type => "timestamp", is_nullable => 1 },
);

__PACKAGE__->set_primary_key("id");

__PACKAGE__->belongs_to(
	"event",
	"WriteOff::Schema::Result::Event",
	{ id => "event_id" },
	{ is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);

__PACKAGE__->has_many(
	"guesses",
	"WriteOff::Schema::Result::Guess",
	{ "foreign.record_id" => "self.id" },
	{ cascade_copy => 0, cascade_delete => 0 },
);

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

__PACKAGE__->has_many(
	"votes",
	"WriteOff::Schema::Result::Vote",
	{ "foreign.record_id" => "self.id" },
	{ cascade_copy => 0, cascade_delete => 0 },
);

sub now_dt {
	return shift->result_source->resultset->now_dt;
}

sub is_filled {
	my $self = shift;

	return defined $self->votes->get_column('value')->next;
}

sub is_empty {
	my $self = shift;

	return $self->votes->count == 0;
}

sub is_unfilled {
	my $self = shift;

	return !$self->is_filled && !$self->is_empty;
}

sub is_fillable {
	my $self = shift;
	my $event = $self->event;

	return $self->round eq 'prelim'  && $event->prelim_votes_allowed
	    || $self->round eq 'private' && $event->private_votes_allowed;
}


sub is_publicly_viewable {
	my $self = shift;

	return $self->round eq 'private' && $self->event->end <= $self->now_dt;
}

sub avg {
	my $self = shift;

	return $self->mean;
}

sub values {
	my $self = shift;

	return $self->votes->get_column('value');
}

sub range {
	my $self = shift;

	return $self->{__range} //=
		$self->round eq 'public'
			? [ 0 .. 10 ]
			: [ sort { $a <=> $b } $self->values->all ];
}

sub recalc_stats {
	my $self = shift;
	my $votes = $self->votes;

	$self->update({
		mean  => $votes->mean,
		stdev => $votes->stdev,
	});
}

1;
