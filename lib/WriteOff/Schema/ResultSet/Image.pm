package WriteOff::Schema::ResultSet::Image;

use strict;
use base 'WriteOff::Schema::Item';

sub metadata {
	return shift->search_rs(undef, {
		columns => [
			'id', 'user_id', 'event_id', 'ip',
			'title', 'artist', 'website', 'hovertext',
			'filesize', 'mimetype',
			'public_score', 'public_stdev',
			'rank', 'rank_low',
			'seed', 'created', 'updated'
		]
	});
}

sub no_contents {
	return shift->metadata->search_rs(undef, {
		'+columns' => [ 'thumb' ],
	});
}

1;
