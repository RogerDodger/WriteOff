package WriteOff::Schema::ResultSet::Post;

use strict;
use warnings;
use base 'WriteOff::Schema::ResultSet';
use List::Util qw/maxstr/;

sub artists_hash {
	my $self = shift;

	# Undo the paging, we want to get all artists in the thread
	my %artists =
		map { $_->id => $_ } $self->fresh
			->search({ event_id => $self->get_column('event_id')->first })
			->related_resultset('artist')
			->all;

	return \%artists;
}

sub fresh {
	shift->result_source->schema->resultset('Post');
}

sub num_for {
	my ($self, $post) = @_;

	$self->search({
		id => { '<=' => $post->id },
		created => { '<=' => $self->format_datetime($post->created) },
	})->count;
}

sub thread {
	my ($self, $page, $rows) = @_;

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
		prefetch => [ 'entry', 'artist' ],
	});
}

sub thread_prefetch_rs {
	scalar shift->thread_prefetch;
}

sub uid {
	my ($self, $eid, $nid) = @_;
	my $pager = $self->pager;

    return join '.', 'thread', $eid // '', $nid // '',
    	$pager->current_page, $pager->entries_per_page,
    	# Using a ->max query doesn't work for some reason. I think it's the paging?
    	maxstr($self->get_column('updated')->all),
		maxstr($self->search({}, { join => 'artist' })->get_column('artist.updated')->all),
}

sub vote_map {
	my ($self, $user) = @_;

	return {} if !$user;

	my %map = map { $_->id => 1 }
		$self->fresh->search(
			{ 'votes.user_id' => $user->id },
			{ join => 'votes' })->all;

	\%map;
}

1;
