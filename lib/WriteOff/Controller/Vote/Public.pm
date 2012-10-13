package WriteOff::Controller::Vote::Public;
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller'; }

=head1 NAME

WriteOff::Controller::Vote::Public - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut

sub fic :PathPart('vote/public') :Chained('/event/fic') :Args(0) {
    my ( $self, $c ) = @_;

	$c->forward('/captcha_get');
	
	my $formid = "form" . "event" . $c->stash->{event}->id . "public" . "fic";
	
	if( $c->req->method eq 'POST' ) {
		if( $c->req->params->{submit} eq 'Save vote' ) {
			$c->session->{$formid} = $c->req->params;
			$c->stash->{status_msg} = 'Vote saved';
		}
		if( $c->req->params->{submit} eq 'Clear vote' ) {
			delete $c->session->{$formid};
			$c->stash->{status_msg} = 'Vote cleared';
		}
		if( $c->req->params->{submit} eq 'Cast vote' ) {
			$c->forward('do_public', [ $formid ]);
		}
	}
	
	$c->stash->{fillform} = $c->session->{$formid} // undef;
	
	push $c->stash->{title}, 'Vote', 'Public';
    $c->stash->{template} = 'vote/public/fic.tt';
}

sub art :PathPart('vote/public') :Chained('/event/art') :Args(0) {
    my ( $self, $c ) = @_;
	
	push $c->stash->{title}, 'Vote', 'Public';
	$c->stash->{template} = 'vote/public/art.tt';
}

sub do_public :Private {
	my ( $self, $c, $formid ) = @_;
	
	return 0 unless $c->stash->{event}->public_votes_allowed;
	
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
	
	my $rs = $c->stash->{event}->vote_records->public->fic;
	
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
			type    => 'fic',
		});
		
		for my $id ( @votes ) {
			$record->create_related('votes', {
				story_id => $id,
				value    => $c->form->valid($id),
			});
		}
		
		delete $c->session->{$formid};
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
