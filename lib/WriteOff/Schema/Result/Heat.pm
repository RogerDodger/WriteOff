use utf8;
package WriteOff::Schema::Result::Heat;

use strict;
use warnings;
use base "WriteOff::Schema::Result";

use constant {
	ELO_K       => 32,
	ELO_BETA    => 400,
};

__PACKAGE__->table("heats");

__PACKAGE__->add_columns(
	"id",
	{ data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
	"left",
	{ data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
	"right",
	{ data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
	"ip",
	{ data_type => "text", is_nullable => 1 },
	"created",
	{ data_type => "timestamp", is_nullable => 1 },
);

__PACKAGE__->set_primary_key("id");

__PACKAGE__->belongs_to(
	"left",
	"WriteOff::Schema::Result::Prompt",
	{ id => "left" },
	{ is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);

__PACKAGE__->belongs_to(
	"right",
	"WriteOff::Schema::Result::Prompt",
	{ id => "right" },
	{ is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);

# Need to define another belongs_to with one of the prompt tables, as joins
# throw exceptions with "left" and "right"

__PACKAGE__->belongs_to(
	"prompt",
	"WriteOff::Schema::Result::Prompt",
	{ id => "left" },
	{ is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);

sub do_heat {
	my ($row, $event, $ip, $result) = @_;
	#$result = { left => 1, tie => 0.5, right => 0 };

	return 0 unless
		defined $result &&
		$row->ip eq $ip &&
		$row->left->event_id == $event->id;

	my ($A, $B) = ($row->left, $row->right);

	my $R_a = $A->rating;
	my $R_b = $B->rating;

	my $E_a = 1 / ( 1 + 10**( ($R_b - $R_a) / ELO_BETA ) );
	my $E_b = 1 / ( 1 + 10**( ($R_a - $R_b) / ELO_BETA ) );

	$A->update({ rating => $R_a + ELO_K * ( $result - $E_a ) });
	$B->update({ rating => $R_b + ELO_K * ( abs($result - 1) - $E_b ) });

	$row->delete;

	0;
}

1;
