package WriteOff::Schema::ResultSet::Post;

use strict;
use warnings;
use base 'WriteOff::Schema::ResultSet';

sub thread {
	my ($self, $page) = @_;

	$page //= 1;

	$self->search_rs({}, {
		prefetch => [
			'artist',
			'entry',

		],
		rows => 100,
		page => $page,
		order_by => { -asc => 'me.created' },
	});
}

# Unique amongst any version of itself, as well as any other set of posts
sub uid {
	my ($self, $user) = @_;

	join('.', 'thread',
		$user->id, $self->count, $self->pager->current_page,
		map { $self->get_column($_)->max } qw/me.id me.updated artist.updated/
	);
}

1;
