package WriteOff::Controller::Event;
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller'; }

=head1 NAME

WriteOff::Controller::Event - Catalyst Controller

=head1 DESCRIPTION

Chained actions for grabbing an event and determining if the requested event 
part allows submissions at the current time.


=head1 METHODS

=cut


=head2 index :PathPart('event') :Chained('/') :CaptureArgs(1)

Grabs event info

=cut

sub index :PathPart('event') :Chained('/') :CaptureArgs(1) {
    my ( $self, $c, $id ) = @_;
	
	$c->stash->{event}  = $c->model('DB::Event')->find($id) or $c->detach('/default');
		
	$c->stash->{images} = $c->model('DB::Image')->search({ event_id => $id }) if
		$c->stash->{event}->has_art;
	$c->stash->{storys} = $c->model('DB::Story')->search({ event_id => $id });
}

sub fic :PathPart('fic') :Chained('index') :CaptureArgs(0) {
	my ( $self, $c ) = @_;

	$c->req->params->{subs_allowed} = 
		$c->model('DB::Event')->fic_subs_allowed( $c->stash->{event} );
}

sub art :PathPart('art') :Chained('index') :CaptureArgs(0) {
	my ( $self, $c ) = @_;

	$c->detach('/error', ['There is no art component to this event.']) unless
		$c->stash->{event}->has_art;
	
	$c->req->params->{subs_allowed} = 
		$c->model('DB::Event')->art_subs_allowed( $c->stash->{event} );
}

sub prompt :PathPart('prompt') :Chained('index') :CaptureArgs(0) {
	my ( $self, $c ) = @_;
	
	$c->req->params->{subs_allowed} = 
		$c->model('DB::Event')->prompt_subs_allowed ( $c->stash->{event} );
	$c->req->params->{votes_allowed} = 
		$c->model('DB::Event')->prompt_votes_allowed( $c->stash->{event} );
}

=head1 AUTHOR

Cameron Thornton

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
