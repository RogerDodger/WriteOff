package WriteOff::Schema::ResultSet::Post;

use strict;
use warnings;
use base 'WriteOff::Schema::ResultSet';

sub thread {
	my ($self, $page) = @_;

	$self->search_rs({}, {
		prefetch => [
			'artist',
			'entry',
		],
		order_by => { -asc => 'me.created' },
		# page => $page =~ /(\d+)/ ? int $1 : 1,
		# rows => 40,
	});
}

1;
