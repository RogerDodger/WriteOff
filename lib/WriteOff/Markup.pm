package WriteOff::Markup;
use utf8;

use 5.01;
use strict;
use warnings;
use Parse::BBCode;

my %tags = (
	b => '<strong>%{parse}s</strong>',
	i => '<em>%{parse}s</em>',
	u => '<span style="text-decoration: underline">%{parse}s</span>',
	s => '<del>%{parse}s</del>',
	url => '<a href="%{link}a">%{parse}s</a>',
	size => '<span style="font-size: %{size}aem;">%{parse}s</span>',
	color => '<span style="color: %{color}a;">%{parse}s</span>',
	smcaps => '<span style="font-variant: small-caps">%{parse}s</span>',
	center => {
		class => 'block',
		output => '<div style="text-align: center">%{parse}s</div>',
	},
	right => {
		class => 'block',
		output => '<div style="text-align: right">%{parse}s</div>',
	},
	quote => {
		class => 'block',
		output => '<blockquote>%{parse}s</blockquote>',
	},
	hr => {
		class => 'block',
		output => '<hr>',
		single => 1,
	},
);

my %escapes = (
	Parse::BBCode::HTML->default_escapes,
	size => sub {
		if ($_[2] =~ /^(\d+(?:\.\d+))(px|em|pt)?$/) {
			my ($em, $unit) = ($1, $2 // '');
			$em /= 16 if $unit eq 'px' || !$unit;
			$em /= 12 if $unit eq 'pt';
			return 0.5 < $em && $em < 4 ? $em : 1;
		}
		else {
			return 1;
		}
	},
	color => sub {
		$_[2] =~ /\A#?[0-9a-zA-Z]+\z/ ? $_[2] : 'inherit';
	},
);

my $post = Parse::BBCode->new({
	tags => {
		%tags,
		q{} => sub {
			my ($parser, $attr, $text, $info) = @_;

			$text = Parse::BBCode::escape_html($text);
			$text =~ s/\r\n|\n\r|\n|\r/<br>/g;

			my $params = $parser->get_params;
			my $posts = $params->{posts} or return $text;
			$params->{limit} //= 50;

			for my $ignore (qw/quote url/) {
				if ($info->{tags}->{$ignore}) {
					return $text;
				}
			}

			$text =~ s{
				(&gt; &gt; ([0-9]+))
			}{
				die "Too many replies in post\n" if $params->{limit}-- <= 0;
				$posts->find($2)
					? qq{<a href="/post/$2" class="Post-reply">$1</a>}
					: $1
			}xeg;

			$text;
		},
	},
	escapes => \%escapes,
});

my $story = Parse::BBCode->new({
	tags => \%tags,
	escapes => \%escapes,
});

sub post {
	$post->render(@_);
}

sub story {
	$story->render(@_);
}

1;
