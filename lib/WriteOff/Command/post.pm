package WriteOff::Command::post;

use WriteOff::Command;

sub run {
	my ($self, $command, @args) = @_;
	if (defined $command && $command =~ /^(?:render)$/) {
		$self->$command(@args);
	}
	else {
		$self->help;
	}
}

sub render {
	my $self = shift;
	if (@_ < 1) {
		$self->help;
	}

	my $id = shift;
	my $posts = $id eq 'all'
		? $self->db('Post')
		: $self->db('Post')->search({ id => $id });

	while (my $post = $posts->next) {
		$post->render;
	}
}

1;
