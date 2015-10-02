package WriteOff::Schema::ResultSet::Prompt;

use strict;
use warnings;
use base 'WriteOff::Schema::ResultSet';

sub ballot {
	my ($self, $offset) = @_;

	$offset ||= 0.5;

	$self->search({}, {
		order_by => {
			-desc => \qq{
				(CAST(
					strftime('%s', created) / CAST(strftime('%s', '2000-01-01') AS REAL)
						* $offset * 4294967296 AS INTEGER)
							* 1103515245 + 12345) % 65536
			},
		},
	});
}

1;
