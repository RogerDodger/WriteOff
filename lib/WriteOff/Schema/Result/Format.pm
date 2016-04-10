use utf8;
package WriteOff::Schema::Result::Format;

use strict;
use warnings;
use base "WriteOff::Schema::Result";
use WriteOff::Util qw/LEEWAY/;

__PACKAGE__->table("formats");

__PACKAGE__->add_columns(
	"id",
	{ data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
	"name",
	{ data_type => "text", is_nullable => 1 },
	"wc_min",
	{ data_type => "integer", is_nullable => 1 },
	"wc_max",
	{ data_type => "integer", is_nullable => 1 },
);

__PACKAGE__->set_primary_key("id");

__PACKAGE__->has_many("events", "WriteOff::Schema::Result::Event", "format_id");
__PACKAGE__->has_many("rounds", "WriteOff::Schema::Result::FormatRound", "format_id");

sub duration {
	shift->rounds
		->search({}, {
			'select'   => [ \"duration + offset" ],
			'as'       => [ 'ttl' ],
		})
		->get_column('ttl')
		->max;
}

sub id_uri {
	my $self = shift;
	return WriteOff::Util::simple_uri $self->id, $self->name;
}

sub timeline {
	my ($self, $t0) = @_;
	my (@timeline, %leeway);

	for my $round ($self->rounds->ordered->all) {
		my $start = $t0->clone->add(days => $round->offset);
		my $end = $start->clone->add(days => $round->duration);

		if ($round->mode eq 'submit') {
			$leeway{$round->offset + $round->duration} = 1;
		}
		$start->add(minutes => LEEWAY) if $leeway{$round->offset};

		push @timeline, {
			name => $round->name,
			start => $start->iso8601,
			end => $end->iso8601,
		};
	}

	\@timeline;
}

1;
