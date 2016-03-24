package WriteOff::Schema::ResultSet::Post;

use strict;
use warnings;
use base 'WriteOff::Schema::ResultSet';

sub artists_hash {
	my $self = shift;

	# Undo the paging, we want to get all artists in the thread
	my %artists =
		map { $_->id => $_ }
			$self->result_source->schema->resultset('Post')
				->search({ event_id => $self->get_column('event_id')->first })
				->related_resultset('artist')
				->all;

	return \%artists;
}

sub thread {
	my ($self, $page, $rows) = @_;

	warn $page;
	$page //= 1;
	$rows //= 100;

	$self->search_rs({}, {
		page => $page,
		rows => $rows,
		order_by => [
			{ -asc => 'me.created' },
			{ -asc => 'me.id' },
		],
	});
}

sub thread_prefetch {
	my $self = shift;

	$self->search({}, {
		prefetch => [
			'entry',
			{ reply_children => 'child' }
		]
	});
}

sub thread_prefetch_rs {
	scalar shift->thread_prefetch;
}

1;
