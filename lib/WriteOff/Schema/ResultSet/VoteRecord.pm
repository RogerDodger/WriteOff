package WriteOff::Schema::ResultSet::VoteRecord;

use strict;
use base 'WriteOff::Schema::ResultSet';

sub filled {
	return shift->search_rs(
		{ 'votes.value' => { '!=' => undef } },
		{ 
			join => 'votes',
			group_by => 'me.id',
		}
	);
}

sub unfilled {
	return shift->search_rs(
		{ 
			'votes.value' => undef, 
			'votes.id' => { '!=' => undef } 
		},
		{
			join => 'votes',
			group_by => 'me.id',
		}
	);
}

sub ordered {
	return shift->order_by([
		{ -asc => 'type' },
		{ -asc => 'updated' },
	]);
}

sub with_stats {
	my $self = shift;
	
	my $votes_rs = $self->result_source->schema->resultset('Vote');
	
	my $mean = $votes_rs->search(
		{
			"votes.record_id" => { '=' => { -ident => 'me.id' } }
		},
		{
			select => [{ avg => 'votes.value' }],
			alias => 'votes',
		}
	);
	
	my $with_mean = $self->search_rs(undef, {
		'+select' => [
			{ '' => $mean->as_query, -as => 'mean' },
		],
		'+as' => [ 'mean' ],
	});
	
	# my $variance = $votes_rs->search(
		# {
			# "votes.record_id" => { '=' => { -ident => 'me.id' } },
		# },
		# {
			# select => [ \'(AVG( (value - mean)*(value - mean) ))' ],
			# alias => 'votes',
		# }
	# );
	
	# my $variance = 
		# '(SELECT AVG( (value - mean)*(value - mean) ) ' .
		# 'FROM votes votes ' .
		# 'WHERE votes.record_id = me.id)';
	
	# my $with_stats = $with_mean->as_subselect_rs->search(undef, {
		# '+select' => [
			# 'mean',
			# $variance,
		# ],
		# '+as' => [ 'mean', 'variance' ],
	# });
	
	# return $with_stats;
}

sub round {	
	return shift->search_rs({ round => shift });
}

sub prelim {
	return shift->round('prelim');
}

sub public {
	return shift->round('public');
}

sub private {
	return shift->round('private');
}

sub type {
	return shift->search_rs({ type => shift })
}

sub fic {
	return shift->type('fic');
}

sub art {
	return shift->type('art');
}

1;