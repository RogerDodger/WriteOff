package WriteOff::Controller::Vote::Public;
use Moose;
use namespace::autoclean;
use Scalar::Util qw/looks_like_number/;

BEGIN { extends 'Catalyst::Controller'; }

=head1 NAME

WriteOff::Controller::Vote::Public - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut

sub fic :PathPart('vote/public') :Chained('/event/fic') :Args(0) {
	my ( $self, $c ) = @_;

	if ($c->stash->{event}->public_votes_allowed) {
		$c->stash->{candidates} = [
			$c->stash->{event}->storys->metadata->seed_order->candidates->all
		];

		$c->forward('do_public') if $c->req->method eq 'POST';
	}

	$c->forward('fillform');

	$c->stash->{votes_received} =
		$c->stash->{event}->vote_records->public->fic->filled->count;

	push $c->stash->{title}, 'Vote', 'Public';
	$c->stash->{template} = 'vote/public/fic.tt';
}

sub art :PathPart('vote/public') :Chained('/event/art') :Args(0) {
	my ( $self, $c ) = @_;

	if ($c->stash->{event}->art_votes_allowed) {
		$c->stash->{candidates} = [
			$c->stash->{event}->images->metadata->seed_order->all
		];

		$c->forward('do_public') if $c->req->method eq 'POST';
	}

	$c->forward('fillform');

	push $c->stash->{title}, 'Vote', 'Public';
	$c->stash->{template} = 'vote/public/art.tt';
}

sub do_public :Private {
	my ( $self, $c ) = @_;
	return unless $c->user;

	# 'fic', 'art', ...
	my $type = $c->action->name;

	my $record = $c->model('DB::VoteRecord')->find_or_create({
		event_id => $c->stash->{event}->id,
		user_id  => $c->user_id,
		round    => 'public',
		type     => $type,
	});

	my $item_id_col = { art => 'image_id', fic => 'story_id' }->{$type};
	if (!defined $item_id_col) {
		$c->log->warn("Unrecognised vote type: $type");
		return;
	}

	my @candidates = @{ $c->stash->{candidates} };
	for my $item (@candidates) {
		# Users cannot vote on their own entries
		next if $item->user_id == $c->user_id;

		my $score = $c->req->param($item->id);
		next unless defined $score;

		my $vote = $c->model('DB::Vote')->find_or_new({
			$item_id_col => $item->id,
			record_id    => $record->id,
		});

		if (looks_like_number($score) && $score >= 0 && 10 >= $score) {
			$vote->insert;
			$vote->update({ value => int $score });
		} elsif ($vote->in_storage) {
			$vote->delete;
		}
	}

	# A record is filled if it has votes for more than half the candidates
	$record->update({ filled => $record->votes->count >= @candidates/2 });
	$record->recalc_stats;

	$c->stash->{status_msg} = 'Vote updated';
}

sub fillform :Private {
	my ($self, $c) = @_;
	return unless $c->user;

	my $record = $c->stash->{event}->vote_records->public->find({
		user_id => $c->user_id,
		type    => $c->action->name,
	});

	if (defined $record) {
		$c->stash->{fillform} = {
			map { $_->item->id => $_->value } $record->votes->all,
		};
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
