package WriteOff::Controller::Admin;
use Moose;
use namespace::autoclean;
use DateTime::Format::MySQL;

BEGIN { extends 'Catalyst::Controller'; }

use constant INTERIM => WriteOff->config->{interim};

=head1 NAME

WriteOff::Controller::Admin - Catalyst Controller

=head1 DESCRIPTION

Controller for performing administrative actions

=head1 METHODS

=head2 auto

Check that the person accessing controller actions is the admin

=cut

sub auto :Private {
	my ( $self, $c ) = @_;
	
	$c->detach('/forbidden', ['You are not the admin.']) unless 
		$c->check_user_roles($c->user, qw/admin/); 
}

=head2 event_add

Create events

=cut

sub event_add :Path('/event/add') :Args(0) {
	my ( $self, $c ) = @_;
	
	$c->stash->{template} = 'event/add.tt';
	
	if($c->req->method eq 'POST') {
	
		$c->form(
			start => [ 'NOT_BLANK', [qw/DATETIME_FORMAT MySQL/] ],
			{ ints => 
			[qw/art_dur fic_dur prelims_dur finals_dur interim wc_min wc_max/] 
			} => [qw/NOT_BLANK INT/],
		);
		
		$c->forward('do_event_add') if !$c->form->has_error;
	}
}

sub do_event_add :Private {
	my ( $self, $c ) = @_;
	
	my $p  = $c->req->params; 
	my $dt = DateTime::Format::MySQL->parse_datetime( $p->{start} );
		
	my %row;
	$row{start}         = $dt->clone;
	$row{prompt_voting} = $dt->add( minutes => INTERIM )->clone;
	
	if( $p->{has_art} ) {
		$row{has_art} = 1;
		$row{art}     = $dt->add( minutes => INTERIM )->clone;
		$row{art_end} = $dt->add( hours => $p->{art_dur} )->clone;
	} 
	else {
		$row{has_art} = 0;
	}
	$row{fic}     = $dt->add( minutes => INTERIM )->clone;
	$row{fic_end} = $dt->add( hours => $p->{fic_dur} )->clone;

	if( $p->{has_prelim} ) {
		$row{has_prelim} = 1;
		$row{prelims}    = $dt->add( minutes => INTERIM )->clone;
		$row{finals}     = $dt->add( days => $p->{prelims_dur} )->clone;
	}
	else {
		$row{has_prelim} = 0;
		$row{finals}     = $dt->add( minutes => INTERIM )->clone;
	}
	$row{end} = $dt->add( days => $p->{finals_dur} )->clone;
	$row{wc_min} = $p->{wc_min};
	$row{wc_max} = $p->{wc_max};
	
	$c->model('DB::Event')->create(\%row);
	$c->stash->{status_msg} = 'Event created';
	return 0;
}

=head1 AUTHOR

Cameron Thornton

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
