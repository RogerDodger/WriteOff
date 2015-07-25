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

sub cast :Private {
	my ($self, $c) = @_;

	if ($c->stash->{round} && $c->user) {
		my $record = $c->stash->{event}->vote_records->search({
			user_id => $c->user->id,
			round   => $c->stash->{round},
			type    => $c->stash->{type},
		})->first;

		if (!$record) {
			$record = $c->stash->{event}->create_related('vote_records', {
				user_id => $c->user->id,
				round => $c->stash->{round},
				type  => $c->stash->{type},
			});

			if ($c->stash->{type} eq 'fic') {
				my $mins = $c->stash->{end}->delta_ms($c->stash->{now})->in_units('minutes');
				my $w = $mins / 1440 * $c->config->{work}{threshold};

				while ($w > 0 && (my $story = $c->stash->{candidates}->next)) {
					$w -= $story->wordcount / $c->config->{work}{rate} + $c->config->{work}{offset};
					$story->create_related('votes', { record_id => $record->id });
				}
			}
		}

		$c->stash->{record} = $record;
		$c->stash->{ordered} = $record->votes->search(
			{ value => { '!=' => undef }},
			{ order_by => { -desc => 'value' }}
		);
		$c->stash->{unordered} = $record->votes->search({ value => undef });
	}

	push $c->stash->{title}, $c->stash->{label} || 'Vote';
	$c->stash->{template} = 'vote/cast.tt';
}

sub fic :PathPart('vote') :Chained('/event/fic') :Args(0) {
	my ($self, $c) = @_;

	my $e = $c->stash->{event};

	$c->stash->{type} = 'fic';
	$c->stash->{view} = $c->controller('Fic')->action_for('view');
	if ($e->fic_end > $e->now_dt) {
		$c->stash->{end} = $e->prelim || $e->public || $e->private;
	}
	elsif ($e->prelim_votes_allowed) {
		$c->stash->{round} = 'prelim';
		$c->stash->{label} = 'Prelims';
		$c->stash->{end} = $e->public;
		$c->stash->{candidates} = $e->storys->eligible->sample;
	} elsif ($e->public_votes_allowed) {
		$c->stash->{round} = 'public';
		$c->stash->{label} = $e->public_label;
		$c->stash->{end} = $e->private || $e->end;
		$c->stash->{candidates} = $e->storys->candidates->sample;
	} elsif ($e->private_votes_allowed) {
		$c->stash->{round} = 'private';
		$c->stash->{label} = 'Finals';
		$c->stash->{end} = $e->end;
		$c->stash->{candidates} = $e->storys->finalists->sample;
	}

	$c->forward('cast');
}

sub prelim :PathPart('vote/prelim') :Chained('/event/fic') :Args(0) {
	my ( $self, $c ) = @_;
	my $e = $c->stash->{event};

	$c->detach('/error', [ $c->strings->{noPrelim} ]) unless $e->prelim;

	if ($c->user) {
		$c->stash->{records} = $e->vote_records->search({
			round   => 'prelim',
			type    => 'fic',
			user_id => $c->user->id,
		});

		$c->stash->{requestable} = !$c->stash->{records}->unfilled->count;

		if ($c->req->method eq 'POST' && $e->prelim_votes_allowed) {
			if ($c->stash->{requestable}) {
				my $err = $e->new_prelim_record_for(
					$c->user, $c->config->{work},
				);

				if ($err) {
					$c->stash->{error_msg} = $err;
				}
				else {
					$c->res->redirect($c->req->uri);
				};
			}
			else {
				$c->stash->{error_msg} = "You have empty records to fill in";
			}
		}
	}

	$c->stash(
		votes_received => $e->vote_records->prelim->filled->count,
	);

	push $c->stash->{title}, 'Vote', 'Prelim';
	$c->stash->{template} = 'vote/rank.tt';
}

sub private :PathPart('vote/private') :Chained('/event/fic') :Args(0) {
	my ( $self, $c ) = @_;
	my $e = $c->stash->{event};

	$c->detach('/error', [ $c->strings->{noPrivate} ]) unless $e->private;

	$c->stash->{record} = $e->vote_records->search({
		round => 'private',
		type => 'fic',
		user_id => $c->user->id
	});

	$c->stash->{finalists} = $e->storys->search(
		{ finalist => 1 },
		{ order_by => 'title' },
	);

	$c->stash(
		judge => $e->judges->find($c->user_id),
		votes_received => $e->vote_records->private->filled->count,
	);

	$c->stash->{records} = $e->vote_records->unfilled->search({
		round    => 'private',
		type     => 'fic',
		user_id  => $c->stash->{judge}->id,
	})->unfilled if $c->stash->{judge};

	push $c->stash->{title}, 'Vote', 'Private';
	$c->stash->{template} = 'vote/rank.tt';
}

=head1 AUTHOR

Cameron Thornton E<lt>cthor@cpan.orgE<gt>

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
