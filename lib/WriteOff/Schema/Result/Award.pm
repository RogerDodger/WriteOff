use utf8;
package WriteOff::Schema::Result::Award;

use strict;
use warnings;
use base "WriteOff::Schema::Result";
use WriteOff::Award;

__PACKAGE__->table("awards");

__PACKAGE__->add_columns(
	"id",
	{ data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
	"entry_id",
	{ data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
	"award_id",
	{ data_type => "integer", is_nullable => 0 },
);

__PACKAGE__->set_primary_key("id");

__PACKAGE__->belongs_to("entry", "WriteOff::Schema::Result::Entry", "entry_id");

for my $meth (qw/alt html name order src tallied title/) {
	eval qq{
		sub $meth {
			WriteOff::Award->new(shift->award_id)->$meth;
		}
	}
}

1;
