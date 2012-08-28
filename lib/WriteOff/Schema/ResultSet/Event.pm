package WriteOff::Schema::ResultSet::Event;

use strict;
use base 'DBIx::Class::ResultSet';
use constant LEEWAY => 5;

sub active_events {	
	my $self = shift;
	return $self->search({end => { '>' => $self->now } });
}

sub old_events {
	my $self = shift;
	return $self->search({end => { '<' => $self->now} });
}

sub fic_subs_allowed {
	my ($self, $row) = @_;
	$row = $self->find($row) if !ref $row;
	
	return $self->check_datetimes_ascend 
	( $row->fic, $self->now_dt, $row->fic_end->clone->add({ minutes => LEEWAY }) );
}

sub art_subs_allowed {
	my ($self, $row) = @_;
	$row = $self->find($row) if !ref $row;
	
	return $self->check_datetimes_ascend 
	( $row->art, $self->now_dt, $row->art_end->clone->add({ minutes => LEEWAY }) );
}

sub prompt_subs_allowed {
	my ($self, $row) = @_;
	$row = $self->find($row) if !ref $row;
	
	return $self->check_datetimes_ascend 
	( $row->start, $self->now_dt, $row->prompt_voting);
}

sub prompt_votes_allowed {
	my ($self, $row) = @_;
	$row = $self->find($row) if !ref $row;
	
	return $self->check_datetimes_ascend 
	( $row->prompt_voting, $self->now_dt, $row->has_art ? $row->art : $row->fic );
}

sub now {	
	my $self = shift;
	return $self->result_source->schema->storage->datetime_parser
		->format_datetime( $self->now_dt );
}

sub now_dt {
	my $fmt = DateTime::Format::Strptime->new( 
		time_zone => 'floating',
		locale    => 'en_AU',
		pattern   => '%F %T',
	);
	
	return $fmt->parse_datetime('2012-12-25 00:06:00');
}

sub check_datetimes_ascend {
	my $self = shift;
	
	return 1 if join('', @_) eq join('', sort @_);
	0;
}

1;