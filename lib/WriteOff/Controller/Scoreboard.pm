package WriteOff::Controller::Scoreboard;
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller'; }

=head1 NAME

WriteOff::Controller::Scoreboard - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=head2 begin

Sets the template.

=cut

sub begin :Private {
	my ( $self, $c ) = @_;
	
	$c->stash->{template} = 'scoreboard.tt';
}

=head2 index

Displays the scoreboard.

=cut

sub index :Path('') :Args(0) {
	my ( $self, $c ) = @_;
	
	$c->stash->{scoreboard} = $c->model('DB::Scoreboard')->ordered->with_pos;
}

=head2 reset

Clears and resets the scoreboard.

=cut

sub reset :Local :Args(0) {
	my ( $self, $c ) = @_;
	
	$c->forward( $c->controller('Root')->action_for('assert_admin') );
	
	$c->forward('clear') unless $c->req->query_keywords eq 'noclear';
	
	$c->forward( $c->controller('Event')->action_for('tally_results'), [ $_ ] ) 
		for $c->model('DB::Event')->finished->get_column('id')->all;
		
	$c->stash->{status_msg} = 'Scoreboard reset';
	
	$c->forward('index');
}

=head2 clear

Clears the scoreboard.

=cut

sub clear :Local :Args(0) {
	my ( $self , $c ) = @_;
	
	$c->forward( $c->controller('Root')->action_for('assert_admin') );
	
	$c->model('DB::Scoreboard')->delete;
	
	$c->stash->{status_msg} = 'Scoreboard cleared';
}

=head1 AUTHOR

Cameron Thornton E<lt>cthor@cpan.orgE<gt>

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
