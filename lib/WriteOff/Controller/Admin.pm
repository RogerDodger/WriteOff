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
		$c->check_user_roles('admin'); 
}

=head2 event_add

Create events

=cut

sub event_add :Path('/event/add') :Args(0) {
	my ( $self, $c ) = @_;
	
	$c->stash->{template} = 'event/add.tt';
	
	if($c->req->method eq 'POST') {
	
		my $p = $c->req->params; 
		$c->form(
			start => [ 'NOT_BLANK', [qw/DATETIME_FORMAT MySQL/] ],
			prompt => [ [ 'LENGTH', 1, $c->config->{len}{max}{prompt} ] ],
			wc_min      => [ 'NOT_BLANK', 'INT' ],
			wc_max      => [ 'NOT_BLANK', 'INT' ],
			fic_dur     => [ 'NOT_BLANK', 'INT' ],
			public_dur  => [ 'NOT_BLANK', 'INT' ],
			art_dur     => [ ($p->{has_art}     ? 'NOT_BLANK' : () ), 'INT'],
			prelim_dur  => [ ($p->{has_prelim}  ? 'NOT_BLANK' : () ), 'INT'],
			private_dur => [ ($p->{has_private} ? 'NOT_BLANK' : () ), 'INT'],
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
		$row{art}     = $dt->add( minutes => INTERIM )->clone;
		$row{art_end} = $dt->add( hours => $p->{art_dur} )->clone;
	} 
	
	$row{fic}     = $dt->add( minutes => INTERIM )->clone;
	$row{fic_end} = $dt->add( hours => $p->{fic_dur} )->clone;
	
	if( $p->{has_prelim} ) {
		$row{prelim} = $dt->add( minutes => INTERIM )->clone;
		$row{public} = $dt->add( days => $p->{prelim_dur} )->clone;
	}
	else {
		$row{public} = $dt->add( minutes => INTERIM )->clone;
	}
	
	if( $p->{has_private} ) {
		$row{private} = $dt->add( days => $p->{public_dur}  )->clone;
		$row{end}     = $dt->add( days => $p->{private_dur} )->clone;
	}
	else {
		$row{end} = $dt->add( days => $p->{public_dur} )->clone;
	}
	
	$row{prompt}   = $c->form->valid('prompt') || 'TBD';
	$row{wc_min}   = $p->{wc_min};
	$row{wc_max}   = $p->{wc_max};
	$row{rule_set} = 1;
	
	my $e = $c->model('DB::Event')->create(\%row);
	
	$c->model('DB::Schedule')->create({
		action => '/event/set_prompt',
		at     => $e->art || $e->fic,
		args   => [$e->id],
	});
	
	$c->model('DB::Schedule')->create({
		action => '/event/prelim_distr',
		at     => $e->prelim,
		args   => [$e->id],
	}) if $p->{has_prelim};
	
	$c->model('DB::Schedule')->create({
		action => '/event/judge_distr',
		at     => $e->private,
		args   => [$e->id],
	}) if $p->{has_private};
	
	$c->model('DB::Schedule')->create({
		action => '/event/tally_results',
		at     => $e->end,
		args   => [$e->id],
	});
	
	$c->flash->{status_msg} = 'Event created';
	$c->res->redirect( $c->uri_for('/') );
}

=head1 AUTHOR

Cameron Thornton E<lt>cthor@cpan.orgE<gt>

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
