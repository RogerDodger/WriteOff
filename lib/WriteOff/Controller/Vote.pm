package WriteOff::Controller::Vote;
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller'; }

=head1 NAME

WriteOff::Controller::Vote - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut


=head2 index

=cut

sub public :PathPart('public') :Chained('/event/vote') :Args(0) {
    my ( $self, $c ) = @_;

    $c->stash->{template} = 'vote/public.tt';
	
	$c->forward('/captcha_get');
	$c->forward('do_public') if $c->req->method eq 'POST';
}

sub do_public :Private {
	my ( $self, $c ) = @_;
	
	my @candidates = $c->stash->{event}->public_story_candidates( $c->user )->all;
	
	#The votes are keyed with the id of the story that the votes are cast on
	my @votes = 
		grep { defined $c->req->params->{$_} && $c->req->params->{$_} ne 'N/A' }
		map  { $_->id }
		grep { $_->ip ne $c->req->address }
		@candidates;
	
	$c->req->params->{count}   = @votes;
	$c->req->params->{ip}      = $c->req->address;
	$c->req->params->{captcha} = $c->forward('/captcha_check');
	
	my $rs = $c->stash->{event}->vote_records->public->story;
	
	$c->form(
		ip       => [ [ 'DBIC_UNIQUE', $rs, 'ip' ] ],
		
		#For whatever reason, FormValidator::Simple doesn't have a >= operator
		count    => [ [ 'GREATER_THAN', @candidates / 2 - 0.001 ] ],
		
		captcha  => [ [ 'EQUAL_TO', 1 ] ],
		map { $_ => [ 'NOT_BLANK', 'UINT', [ 'BETWEEN', 0, 10 ] ] } @votes,
	);
	
	if( !$c->form->has_error ) {
		my $record = $c->stash->{event}->create_related('vote_records', {
			user_id => $c->user ? $c->user->get('id') : undef,
			ip      => $c->req->address,
			round   => 'public',
		});
		
		for my $id ( @votes ) {
			$record->create_related('votes', {
				story_id => $id,
				value    => $c->form->valid($id),
			});
		}
		
		$c->stash->{status_msg} = 'Vote successful';
	}
}


=head1 AUTHOR

Cameron Thornton E<lt>cthor@cpan.orgE<gt>

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
