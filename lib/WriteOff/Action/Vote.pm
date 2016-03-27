package WriteOff::Action::Vote;

use base 'Catalyst::Action';
use 5.014;

sub execute {
	my (undef, $self, $c) = @_;

	return if !$c->user;
	$c->forward('/check_csrf_token');

	my $model  = $self->config->{model} || (ref $self || $self) =~ s/.*:://r;
	my $key    = $self->config->{fetch} || lc $model;
	my $target = $c->stash->{$key} or return;
	my $value  = $c->req->param('value') or return;

	# Vote values other than 1 can be allowed by changing the $value regex
	return unless $value =~ /^1$/;

	my $vote = $c->model("DB::${model}Vote")->find_or_create({
		user_id => $c->user->id,
		"${key}_id" => $target->id,
	});

	if ($vote->value && $vote->value == $value) {
		$vote->delete;
	}
	else {
		$vote->update({ value => $value });
	}

	$target->update({ score => $target->votes->get_column('value')->sum // 0 });

	if ($c->stash->{ajax}) {
		$c->stash->{json} = {
			vote => $vote->in_storage ? int $value : 0,
			score => $model eq 'Post' ? $target->score : undef,
		};
		$c->forward('View::JSON');
	}
	else {
		$c->res->redirect($c->stash->{redirect});
	}
}

1;
