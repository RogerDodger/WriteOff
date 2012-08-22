package WriteOff::Controller::Admin;
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller'; }

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


=head2 index

=cut

sub index :Path :Args(0) {
    my ( $self, $c ) = @_;

    $c->stash->{template} = 'admin/index.tt';
}

=head2 event_add

Create events

=cut

sub event_add :Path('/event/add') :Args(0) {
	my ( $self, $c ) = @_;
	
	$c->stash->{template} = 'event/add.tt';
	
	$c->stash->{error_msg} = $c->forward('do_event_add') if $c->req->method eq 'POST';
}

sub do_event_add :Private {
	my ( $self, $c ) = @_;
	
	my $fmt = DateTime::Format::Strptime->new( 
		time_zone => 'floating',
		locale    => 'en_AU',
		pattern   => '%F %T',
	);
	my $p  = $c->req->params; 
	my $dt = $fmt->parse_datetime($p->{start}) || 
		return 'Invalid starting date (Format: yyyy-mm-dd hh:mm:ss)';
	return "You can't create an event in the past!" if (DateTime->now cmp $dt) > 0;
		
	my %row;
	$row{start}         = $dt->clone;
	$row{prompt_voting} = $dt->add( hours => $p->{interim} )->clone;
	
	if( $p->{has_art} ) {
		$row{has_art} = 1;
		$row{art}     = $dt->add( hours => $p->{interim} )->clone;
		$row{art_end} = $dt->add( hours => $p->{art_dur} )->clone;
	} 
	else {
		$row{has_art} = 0;
	}
	$row{fic}     = $dt->add( hours => $p->{interim} )->clone;
	$row{fic_end} = $dt->add( hours => $p->{fic_dur} )->clone;

	if( $p->{has_prelim} ) {
		$row{has_prelim} = 1;
		$row{prelims}    = $dt->add( hours => $p->{interim} )->clone;
		$row{finals}     = $dt->add( days => $p->{prelims_dur} )->clone;
	}
	else {
		$row{has_prelim} = 0;
		$row{finals}     = $dt->add( hours => $p->{interim} )->clone;
	}
	$row{end} = $dt->add( days => $p->{finals_dur} )->clone;
	
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
