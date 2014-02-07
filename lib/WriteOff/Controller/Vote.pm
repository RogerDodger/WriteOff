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

sub prelim :PathPart('vote/prelim') :Chained('/event/fic') :Args(0) {
	my ( $self, $c ) = @_;

	$c->detach('/error', [ "There is no preliminary voting round for this event." ])
		unless $c->stash->{event}->prelim;

	$c->stash->{records} = $c->stash->{event}->vote_records->unfilled->search({
		round   => 'prelim',
		type    => 'fic',
		user_id => $c->user->get('id'),
	}) if $c->user;

	if (
		$c->user &&
		$c->req->method eq 'POST' &&
		$c->stash->{event}->prelim_votes_allowed
	) {
		if ($c->stash->{records}->count) {
			$c->stash->{event}->new_prelim_record_for(
				$c->user, $c->config->{prelim_distr_size}
			);
		}
		else {
			$c->stash->{error_msg} = "You have empty records to fill in";
		}
	}

	push $c->stash->{title}, 'Vote', 'Prelim';
	$c->stash->{template} = 'vote/prelim.tt';
}

sub private :PathPart('vote/private') :Chained('/event/fic') :Args(0) {
	my ( $self, $c ) = @_;

	$c->detach('/error', [ "There is no private judging for this event." ])
		unless $c->stash->{event}->private;

	$c->stash->{finalists} = $c->stash->{event}->storys->search(
		{ is_finalist => 1 },
		{ order_by => 'title'},
	);

	$c->stash->{judge} =
		$c->stash->{event}->judges->find( $c->user_id );

	$c->stash->{records} = $c->stash->{event}->vote_records->unfilled->search({
		round    => 'private',
		type     => 'fic',
		user_id  => $c->stash->{judge}->id,
	})->unfilled if $c->stash->{judge};

	push $c->stash->{title}, 'Vote', 'Private';
	$c->stash->{template} = 'vote/private.tt';
}


=head1 AUTHOR

Cameron Thornton E<lt>cthor@cpan.orgE<gt>

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
