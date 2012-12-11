package WriteOff::Schema::ResultSet::Image;

use strict;
use base 'WriteOff::Schema::ResultSet';

sub metadata {
	return shift->search_rs(undef, {
		columns => [ 
			'id', 'user_id', 'event_id', 'ip',
			'title', 'artist', 'website', 'hovertext',
			'filesize', 'mimetype',
			'seed', 'created', 'updated'
		]
	});
}

sub no_contents {
	return shift->metadata->search_rs(undef, {
		'+columns' => [ 'thumb' ],
	});
}

sub with_scores {
	my $self = shift;
	
	my $vote_rs = $self->result_source->schema->resultset('Vote');
	my $rel_rs = $self->result_source->schema->resultset('ImageStory');

	my $public = $vote_rs->public->search(
		{ 'public.image_id' => { '=' => { -ident => 'me.id' } } },
		{
			select => [{ avg => 'public.value' }],
			alias => 'public',
		}
	);
	
	my $story_count = $rel_rs->search(
		{ 'rels.image_id' => { '=' => { -ident => 'me.id' } } },
		{
			select => [{ count => 'rels.image_id' }],
			alias => 'rels',
		}
	);
	
	my $with_scores = $self->search_rs(undef, {
		'+select' => [
			{ '' => $public->as_query, -as => 'public_score' },
			{ '' => $story_count->as_query, -as => 'story_count' },
		],
		'+as' => [ 'public_score', 'story_count' ],
		order_by => [
			{ -desc => 'story_count + (CASE WHEN public_score THEN public_score ELSE 0 END)' },
			{ -asc  => 'title' },
		],
	});
}

1;