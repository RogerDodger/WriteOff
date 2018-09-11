use utf8;
package WriteOff::Schema::Result::Ballot;

use strict;
use warnings;
use base "WriteOff::Schema::Result";

__PACKAGE__->table("ballots");

__PACKAGE__->add_columns(
	"id",
	{ data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
	"event_id",
	{ data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
	"round_id",
	{ data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
	"poll_id",
	{ data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
	"user_id",
	{ data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
	"deviance",
	{ data_type => "real", is_nullable => 1 },
	"absolute",
	{ data_type => "bit", default_value => 0, is_nullable => 0 },
	"created",
	{ data_type => "timestamp", is_nullable => 1 },
	"updated",
	{ data_type => "timestamp", is_nullable => 1 },
);

__PACKAGE__->set_primary_key("id");

__PACKAGE__->belongs_to("event", "WriteOff::Schema::Result::Event", "event_id");
__PACKAGE__->belongs_to("round", "WriteOff::Schema::Result::Round", "round_id");
__PACKAGE__->belongs_to("poll", "WriteOff::Schema::Result::Poll", "poll_id");
__PACKAGE__->belongs_to("user", "WriteOff::Schema::Result::User", "user_id");
__PACKAGE__->has_many("votes", "WriteOff::Schema::Result::Vote", "ballot_id");

sub abstains {
	my $self = shift;
	return 1 + int($self->votes->count / 10) - $self->votes->search({ abstained => 1 })->count;
}

sub now_dt {
	return shift->result_source->resultset->now_dt;
}

# TODO: delete all this

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
	return 0;

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

sub recalibrate {
	# For prelim/private records, if an entry becomes disqualified, we need to
	# recalculate the scores of already filled records
	my $self = shift;
	return if $self->round eq 'public' || !$self->filled;

	my $votes = $self->votes;
	my ($n, $i) = ($votes->count - 1, 0);
	for my $vote ($votes->order_by({ -desc => 'value' })->all) {
		my $value = $n - 2 * $i++;
		$vote->update({
			value => $value,
			percentile => 100*($value + $n)/(2*$n),
		});
	}
}

1;
