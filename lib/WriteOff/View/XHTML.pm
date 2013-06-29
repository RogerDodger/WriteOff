package WriteOff::View::XHTML;
use utf8;
use Moose;

extends 'WriteOff::View::HTML';

__PACKAGE__->config(
	WRAPPER			   => '',
	expose_methods => [ qw/ bb_render_xhtml / ],
);

after process => sub {
	my ( $self, $c ) = @_;
	$c->response->headers->{'content-type'} =~ s|text/html|application/xhtml+xml|;
	$c->response->headers->push_header(Vary => 'Accept');
};

my $bbx = Parse::BBCode->new({
	tags => {
		b => '<strong>%{parse}s</strong>',
		i => '<em>%{parse}s</em>',
		u => '<span style="text-decoration: underline">%{parse}s</span>',
		s => '<del>%{parse}s</del>',
		url => '<a class="link new-tab" href="%{link}a">%{parse}s</a>',
		size => '<span style="font-size: %{size}aem;">%{parse}s</span>',
		color => '<span style="color: %{color}a;">%{parse}s</span>',
		smcaps => '<span style="font-variant: small-caps">%{parse}s</span>',
		center => {
			class => 'block',
			output => '<div style="text-align: center">%{parse}s</div>',
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
	},
	escapes => {
		Parse::BBCode::HTML->default_escapes,
		size => sub {
			$_[2] !~ /\D/ &&
			8 <= $_[2] && $_[2] <= 72 ?
			$_[2] / 16 : 1;
		},
		color => sub {
			$_[2] =~ /\A#?[0-9a-zA-Z]+\z/ ? $_[2] : 'inherit';
		},
	},
	linebreaks => 0,
});

sub bb_render_xhtml {
	my ( $self, $c, $text ) = @_;

	return '' unless $text;

	$text = $bbx->render( $text );

	# Replace \n with properly closed <br /> since BBCode parser can't do that
#	$text =~ s/\n/<br \/>/g;

	# Remove line breaks that immediately follow blocks
	for my $block ( '<hr>', '</blockquote>', '</div>' ) {
		my $e = quotemeta $block;
		$text =~ s/$e\K\s*?<br \/>//g;
	}
	# turn each line into it's own <p>
	$text  = '<p>' . join('</p><p>',split  /^/m, $text ) . '</p>';
	#remove all \n
	$text =~ s/\n//g;
	return $text;
}
1;
