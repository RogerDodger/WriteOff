package WriteOff::Schema::ResultSet::Post;

use strict;
use warnings;
use base 'WriteOff::Schema::ResultSet';

sub thread {
	my ($self, $page, $rows) = @_;

	$page //= 1;
	$rows //= 100;

	$self->search_rs({}, {
		prefetch => [
			'artist',
			'entry',
		],
		page => $page,
		rows => $rows,
		order_by => [
			{ -asc => 'me.created' },
			{ -asc => 'me.id' },
		],
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
