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

sub init :Private {
	my ( $self, $c ) = @_;
	
	$c->forward('/captcha_get');
	
	$c->stash->{formid} = join "|", 
		'form', 'event', $c->stash->{event}->id, 'public', $c->action->name;
		
	push $c->stash->{title}, 'Vote', 'Public';
}

sub fic :PathPart('vote/public') :Chained('/event/fic') :Args(0) {
    my ( $self, $c ) = @_;

	$c->forward('init');
	
	if( $c->stash->{event}->public_votes_allowed ) 
	{
		$c->stash->{candidates} = [ $c->stash->{event}->public_story_candidates ];
		
		$c->forward('first_pass') if $c->req->method eq 'POST';
	}
	
    $c->stash->{template} = 'vote/public/fic.tt';
}

sub art :PathPart('vote/public') :Chained('/event/art') :Args(0) {
    my ( $self, $c ) = @_;

	$c->forward('init');
	
	if( $c->stash->{event}->art_votes_allowed ) 
	{
		$c->stash->{candidates} = [ $c->stash->{event}->images->metadata->all ];
		
		$c->forward('first_pass') if $c->req->method eq 'POST';
	}
	
    $c->stash->{template} = 'vote/public/art.tt';
}

sub first_pass :Private {
	my ( $self, $c ) = @_;
	
	if( $c->req->params->{submit} eq 'Save vote' ) 
	{
		$c->session->{ $c->stash->{formid} } = $c->req->params;
		$c->stash->{status_msg} = 'Vote saved';
	}
	
	elsif( $c->req->params->{submit} eq 'Clear vote' ) 
	{
		delete $c->session->{ $c->stash->{formid} };
		$c->stash->{status_msg} = 'Vote cleared';
	}
	
	elsif( $c->req->params->{submit} eq 'Cast vote' ) 
	{
		$c->forward('do_public');
	}
	
}

sub do_public :Private {
	my ( $self, $c ) = @_;
	
	my $candidates = $c->stash->{candidates};
	
	#The votes are keyed with the id of the story that the votes are cast on
	my @votes = 
		grep { defined $c->req->params->{$_} && $c->req->params->{$_} ne 'N/A' }
		map  { $_->id }
		grep { $_->user_id != $c->user_id }
		@$candidates;
	
	$c->req->params->{count}   = @votes;
	$c->req->params->{user_id} = $c->user_id;
	$c->req->params->{captcha} = $c->forward('/captcha_check');
	
	my $rs = $c->stash->{event}->vote_records->public->type( $c->action->name );
	
	$c->form(
		user_id  => [ [ 'DBIC_UNIQUE', $rs, 'user_id' ] ],
		
		#For whatever reason, FormValidator::Simple doesn't have a >= operator
		count    => [ [ 'GREATER_THAN', @$candidates / 2 - 0.001 ] ],
		
		captcha  => [ [ 'EQUAL_TO', 1 ] ],
		map { $_ => [ 'NOT_BLANK', 'UINT', [ 'BETWEEN', 0, 10 ] ] } @votes,
	);
	
	if( !$c->form->has_error ) {
		my %id = (
			fic => 'story_id',
			art => 'image_id',
		);
		
		$c->stash->{event}->create_related('vote_records', {
			user_id => $c->user ? $c->user->get('id') : undef,
			ip      => $c->req->address,
			round   => 'public',
			type    => 'fic',
			votes   => [ map {
				{ 
					$id{ $c->action->name } => $_, 
					value => $c->form->valid($_) 
				}
			} @votes ]
		});
		
		delete $c->session->{ $c->stash->{formid} };
		$c->stash->{status_msg} = 'Vote successful';
	}
}

sub end :Private {
	my ( $self, $c ) = @_;
	
	$c->stash->{fillform} = $c->session->{ $c->stash->{formid} };
	
	$c->forward('/end');
}

=head1 AUTHOR

Cameron Thornton E<lt>cthor@cpan.orgE<gt>

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
