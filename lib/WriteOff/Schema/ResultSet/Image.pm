package WriteOff::Schema::ResultSet::Image;

use strict;
use base 'WriteOff::Schema::Item';

sub difficulty { 50 }

sub metadata {
	return shift->search_rs(undef, {
		columns => [
			'id', 'user_id', 'event_id', 'ip',
			'title', 'artist', 'website', 'hovertext',
			'filesize', 'mimetype', 'version',
			'public_score', 'public_stdev',
			'rank', 'rank_low',
			'seed', 'created', 'updated'
		]
	});
}

sub order_by_score {
	return shift->order_by({ -desc => 'public_score' });
}

sub recalc_public_stats {
	my $self = shift;

	$self->next::method;

	$self->update({
		public_score => \q{
			public_score +
				(SELECT COUNT(*)
					FROM image_story
					WHERE image_id = images.id)
		},
	});
}

1;
