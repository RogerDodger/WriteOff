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
    my ( $self, $c, $arg ) = @_;
	
	my $id = eval { no warnings; int $arg };
	$c->stash->{event} = $c->model('DB::Event')->find($id) or 
		$c->detach('/default');
	
	if( $arg ne $c->stash->{event}->id_uri ) {
		$c->res->redirect
		( $c->uri_for( $c->action, [ $c->stash->{event}->id_uri ] ) );
	}
}

sub fic :PathPart('fic') :Chained('index') :CaptureArgs(0) {
	my ( $self, $c ) = @_;
	
}

sub art :PathPart('art') :Chained('index') :CaptureArgs(0) {
	my ( $self, $c ) = @_;

	$c->detach('/error', ['There is no art component to this event.']) unless
		$c->stash->{event}->art;
}

sub prompt :PathPart('prompt') :Chained('index') :CaptureArgs(0) {
	my ( $self, $c ) = @_;
	
}

sub vote :PathPart('vote') :Chained('index') :CaptureArgs(0) {
	my ( $self, $c ) = @_;
	
}

sub rules :PathPart('rules') :Chained('index') :Args(0) {
	my ( $self, $c ) = @_;
	
	$c->stash->{template} = 'event/rules.tt';
}

sub edit :PathPart('edit') :Chained('index') :Args(0) {
	my ( $self, $c ) = @_;
	
	$c->detach('/forbidden', ['You cannot edit this item.']) unless 
		$c->check_user_roles( $c->user, qw/admin/ );
	
	$c->forward('do_edit') if $c->req->method eq 'POST';
	
	$c->stash->{template} = 'event/edit.tt';
}

sub do_edit :Private {
	my ( $self, $c ) = @_;
	
	$c->form( 
		blurb => [ [ 'LENGTH', 1, $c->config->{biz}{blurb}{max} ] ],
		sessionid => [ 'NOT_BLANK', ['IN_ARRAY', $c->sessionid] ],
	);
	
	if(!$c->form->has_error) {
		$c->stash->{event}->update({ blurb => $c->form->valid('blurb') });
		$c->flash->{status_msg} = 'Edit successful';
		$c->res->redirect( $c->uri_for('/') );
	}
	
}

sub set_prompt :Private {
	my ( $self, $c, $id ) = @_;
	
	my $e = $c->model('DB::Event')->find($id) or return 0;
	my $p = $e->prompts->search(undef, { order_by => { -desc => 'rating' } });
	
	$e->update({ prompt => $p->first->contents });
}

sub prelim_distr :Private {
	my ( $self, $c, $id ) = @_;
	
	my $e = $c->model('DB::Event')->find($id) or return 0;
	
	#blah blah blah
}

sub judge_distr :Private {
	my ( $self, $c, $id ) = @_;

	my $e = $c->model('DB::Event')->find($id) or return 0;
	
	#blah blah blah
}

sub tally_results :Private {
	my ( $self, $c, $id ) = @_;

	my $e = $c->model('DB::Event')->find($id) or return 0;
	
	#blah blah blah
}

=head1 AUTHOR

Cameron Thornton E<lt>cthor@cpan.orgE<gt>

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
