package WriteOff::Command::post;

use WriteOff::Command;

can render =>
	sub {
		my $posts = shift;

		while (my $post = $posts->next) {
			$post->render;
		}
	},
	which => q{
		Renders post with id POST. Renders all posts if POST eq 'all'.
	},
	fetch => 'all';

can render_children =>
	sub {
		my $posts = shift;

		while (my $post = $posts->next) {
			$post->_render_children;
		}
	},
	which => q{
		Renders children for post with id POST. Renders all if POST eq 'all'.
	},
	fetch => 'all';

1;
