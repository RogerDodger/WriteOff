package WriteOff::Controller::Event;
use Moose;

use List::Util qw/shuffle/;
use WriteOff::Award qw/:all/;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller'; }

sub fetch :Chained('/') :PathPart('event') :CaptureArgs(1) :ActionClass('~Fetch') {}

# # Uncomment for debugging
# sub e :Chained('fetch') :PathPart('e') :Args(0) {
# 	my ($self, $c) = @_;
# 	$c->stash->{trigger} = $c->model('DB::EmailTrigger')->find({ name => 'promptSelected' });
# 	$c->forward('/event/notify_mailing_list');
# }

sub permalink :Chained('fetch') :PathPart('') :Args(0) {
	my ( $self, $c ) = @_;

	$c->stash->{event}{nocollapse} = 1;
	$c->stash->{template} = 'event/view.tt';

	if ($c->stash->{event}->commenting) {
		$c->forward('/prepare_thread', [ $c->stash->{event}->posts_rs ]);
	}

	if ($c->stash->{format} eq 'json') {
		$c->stash->{json} = $c->stash->{event}->json;
		$c->forward('View::JSON');
	}
}

sub add :Local :Args(0) {
	my ( $self, $c ) = @_;

	$c->forward('/assert_admin');

	$c->stash->{genres} = $c->model('DB::Genre');
	$c->stash->{formats} = $c->model('DB::Format');

	push @{ $c->stash->{title} }, 'Add Event';
	$c->stash->{template} = 'event/add.tt';

	if ($c->req->method eq 'POST') {
		$c->forward('/check_csrf_token');

		$c->form(
			start => [ 'NOT_BLANK', [qw/DATETIME_FORMAT RFC3339/] ],
			content_level => [ 'NOT_BLANK', [ 'IN_ARRAY', qw/E T M/ ] ],
			format => [
				'NOT_BLANK',
				[ 'NOT_DBIC_UNIQUE', $c->model('DB::Format'), 'id' ],
			],
			genre => [
				'NOT_BLANK',
				[ 'NOT_DBIC_UNIQUE', $c->model('DB::Genre'), 'id' ],
			],
			wc_min => [ qw/NOT_BLANK UINT/ ],
			wc_max => [ qw/NOT_BLANK UINT/ ],
			fic_dur    => [ qw/NOT_BLANK UINT/ ],
			prelim_dur => [ qw/NOT_BLANK UINT/ ],
			final_dur => [ qw/NOT_BLANK UINT/ ],
		);

		$c->forward('do_add') if !$c->form->has_error;
	}
}

sub do_add :Private {
	my ( $self, $c ) = @_;

	my $start = $c->form->valid('start');

	$c->stash->{event} = $c->model('DB::Event')->create({
		prompt        => 'TBD',
		genre_id      => $c->form->valid('genre'),
		format_id     => $c->form->valid('format'),
		content_level => $c->form->valid('content_level'),
		wc_min        => $c->form->valid('wc_min'),
		wc_max        => $c->form->valid('wc_max'),
	});

	$c->stash->{event}->add_to_users($c->user, { role => 'organiser' });

	my $writing = $c->stash->{event}->create_related('rounds', {
		name => 'writing',
		mode => 'fic',
		action => 'submit',
		start => $start,
		end => $start->clone->add(hours => $c->form->valid('fic_dur')),
	});

	my $prelim = $c->stash->{event}->create_related('rounds', {
		name => 'prelim',
		mode => 'fic',
		action => 'vote',
		start => $writing->end_leeway,
		end => $writing->end->clone->add(days => $c->form->valid('prelim_dur')),
	});

	my $final = $c->stash->{event}->create_related('rounds', {
		name => 'final',
		mode => 'fic',
		action => 'vote',
		start => $prelim->end,
		end => $prelim->end->clone->add(days => $c->form->valid('final_dur')),
	});

	$c->stash->{event}->reset_jobs;
	$c->stash->{trigger} = $c->model('DB::EmailTrigger')->find({ name => 'eventCreated' });
	$c->forward('/event/notify_mailing_list');

	$c->flash->{status_msg} = 'Event created';
	$c->res->redirect( $c->uri_for('/') );
}

sub fic :Chained('fetch') :PathPart('fic') :CaptureArgs(0) {
	my ( $self, $c ) = @_;

	$c->detach('/error', ['There is no fic component to this event.'])
		unless $c->stash->{event}->has('fic');

	push @{ $c->stash->{title} }, 'Fic';
}

sub art :Chained('fetch') :PathPart('art') :CaptureArgs(0) {
	my ( $self, $c ) = @_;

	$c->detach('/error', ['There is no art component to this event.'])
	unless $c->stash->{event}->has('art');

	push @{ $c->stash->{title} }, 'Art';
}

sub prompt :Chained('fetch') :PathPart('prompt') :CaptureArgs(0) {
	my ( $self, $c ) = @_;

	push @{ $c->stash->{title} }, 'Prompt';
}

sub vote :Chained('fetch') :PathPart('vote') :CaptureArgs(0) {
	my ( $self, $c ) = @_;

	$c->detach('/error', ['There is no voting component to this event.'])
		unless $c->stash->{event}->has('voting');

	push @{ $c->stash->{title} }, 'Vote';
}

sub rules :Chained('fetch') :PathPart('rules') :Args(0) {
	my ( $self, $c ) = @_;

	$c->stash->{template} = 'event/rules.tt';
	push @{ $c->stash->{title} }, 'Rules';
}

sub results :Private {
	my ( $self, $c ) = @_;

	# Copy this now since we're going to overwrite with a prefetched RS
	my $entrys_clean = $c->stash->{entrys};

	$c->stash->{theorys} = $c->stash->{event}->theorys->search({ mode => $c->stash->{mode} });

	# Lazy load this since we don't want to make DB hits if the template cache
	# comes through
	$c->stash->{graph} = sub {
		{
			theorys => [
				$c->stash->{theorys}->search({}, {
					join => [qw/artist guesses/],
					group_by => [ 'me.id' ],
					having => [ \'count(guesses.id) >= 1' ],
					order_by => [
						{ -desc => 'me.accuracy' },
						{ -asc => 'artist.name' },
					],
					columns => [qw/me.id me.artist_id me.accuracy/],
					'+columns' => {
						'artist_name' => 'artist.name',
					},
					result_class => 'DBIx::Class::ResultClass::HashRefInflator',
				}),
			],
			artists => [
				map {{ id => $_->id, name => $_->name }}
					values %{ $entrys_clean->artists_hash }
			],
			entrys => [
				$entrys_clean->search({}, {
					columns => [qw/me.id me.artist_id me.title/],
					result_class => 'DBIx::Class::ResultClass::HashRefInflator',
				})
			],
			guesses => [
				$c->model('DB::GuessX')->search({}, {
					bind => [$c->stash->{event}->id],
					result_class => 'DBIx::Class::ResultClass::HashRefInflator',
				})
			],
		}
	};

	$c->stash->{entrys} = $c->stash->{entrys}->search({}, {
		prefetch => [ qw/artist awards ratings/ ],
		order_by => [
			{ -asc => 'rank' },
			{ -asc => 'title' },
		],
	});

	my $rounds = $c->stash->{event}->rounds->search(
		{
			mode => $c->stash->{mode},
			action => 'vote',
		},
		{
			order_by => { -desc => 'end' },
		}
	);

	$c->stash->{final} = $rounds->first;

	# Filter out rounds without ratings
	$c->stash->{rounds} = [grep { $_->ratings->count } $rounds->all];

	for my $round (@{ $c->stash->{rounds} }) {
		$round->{has_error} = $round->ratings->search({ error => { "!=" => undef }})->count;
	}

	$c->stash->{ratings} = $c->model('DB::Rating');

	push @{ $c->stash->{title} }, $c->string($c->stash->{mode} . 'Results');
	$c->stash->{template} = 'event/results.tt';
}

sub view :Chained('fetch') :PathPart('submissions') :Args(0) {
	my ( $self, $c ) = @_;

	$c->forward( $self->action_for('assert_organiser') );

	$c->detach('/default', [ 'Page under development...' ]);
}

sub edit :Chained('fetch') :PathPart('edit') :Args(0) {
	my ( $self, $c ) = @_;

	$c->forward('assert_organiser');

	if ($c->req->method eq 'POST') {
		$c->forward('/check_csrf_token');

		$c->form(
			blurb => [ [ 'LENGTH', 1, $c->config->{len}{max}{blurb} ] ],
			rules => [ [ 'LENGTH', 1, $c->config->{len}{max}{rules} ] ],
			content_level => [ 'NOT_BLANK', [ 'IN_ARRAY', qw/E T M/ ] ],
		);

		$c->forward('do_edit') if !$c->form->has_error;
	}

	$c->stash->{fillform} = {
		content_level => $c->stash->{event}->content_level,
		blurb => $c->stash->{event}->blurb,
		rules => $c->stash->{event}->custom_rules,
	};

	push @{ $c->stash->{title} }, 'Edit';
	$c->stash->{template} = 'event/edit.tt';
}

sub do_edit :Private {
	my ($self, $c) = @_;

	if ($c->req->param('submit') eq 'Edit details') {
		$c->stash->{event}->update({
			blurb         => $c->form->valid('blurb'),
			custom_rules  => $c->form->valid('rules'),
			content_level => $c->form->valid('content_level'),
		});

		$c->stash->{status_msg} = 'Details edited';
	}
}

sub assert_organiser :Private {
	my ( $self, $c, $msg ) = @_;

	$c->user->organises($c->stash->{event})
		or $c->detach('/forbidden', [ $c->string('notOrganiser') ]);
}

sub notify_mailing_list :Private {
	my ($self, $c) = @_;

	return unless $c->stash->{trigger};

	$c->log->info("Sending mail for Event %d %s",
		$c->stash->{event}->id,
		$c->stash->{trigger}->name,
	);

	$c->stash->{email} = {
		users => $c->model('DB::User')->subscribers(
			trigger_id => $c->stash->{trigger}->id,
			genre_id => $c->stash->{event}->genre_id,
			format_id => $c->stash->{event}->format_id,
		),
		subject => $c->stash->{trigger}->prompt_in_subject
			? (sprintf "%s %s",
				$c->stash->{event}->prompt,
				$c->string($c->stash->{trigger}->name))
			: (sprintf "%s %s %s", map $c->string($_),
				$c->stash->{event}->genre->name,
				$c->stash->{event}->format->name,
				$c->stash->{trigger}->name),
		template => $c->stash->{trigger}->template,
	};

	$c->stash->{bulk} = 1;
	$c->forward('View::Email');
}

sub set_prompt :Private {
	my ( $self, $c, $id ) = @_;

	$c->stash->{event} = $c->model('DB::Event')->find($id) or return 0;

	# In case of tie, we take the first, which is random
	my @p = shuffle $c->stash->{event}->prompts->all;
	my $best = $p[0];
	for my $p (@p) {
		if ($p->score > $best->score) {
			$best = $p;
		}
	}

	if ($best) {
		$c->stash->{event}->update({ prompt => $best->contents });
	}

	$c->stash->{trigger} = $c->model('DB::EmailTrigger')->find({ name => 'promptSelected' });
	$c->forward('/event/notify_mailing_list');
}

sub check_rounds :Private {
	my ($self, $c, $id ) = @_;

	$c->stash->{event} = $c->model('DB::Event')->find($id) or return 0;

	$c->stash->{trigger} = $c->model('DB::EmailTrigger')->find({ name => 'votingStarted' });
	$c->forward('/event/notify_mailing_list');
}

sub tally_round :Private {
	my ( $self, $c, $eid, $rid ) = @_;

	my $e = $c->model('DB::Event')->find($eid) or return;
	my $r = $c->model('DB::Round')->find($rid) or return;

	$c->log->info("Tallying %s %s round for %s", $r->mode, $r->name, $e->prompt);
	$r->tally($c->config->{work});

	if ($r->name eq 'final') {
		$c->log->info("Tallying %s results for %s", $r->mode, $e->prompt);

		$e->theorys->search({ mode => $r->mode })->process if $e->guessing;
		$e->score($r->mode);

		if ($r->mode eq 'fic') {
			$c->stash->{event} = $e;
			$c->stash->{trigger} = $c->model('DB::EmailTrigger')->find({ name => 'resultsUp' });
			$c->forward('/event/notify_mailing_list');
		}
	}

	$r->update({ tallied => 1 });
}

=head1 AUTHOR

Cameron Thornton E<lt>cthor@cpan.orgE<gt>

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
