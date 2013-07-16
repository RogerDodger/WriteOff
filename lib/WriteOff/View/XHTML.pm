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

sub bb_render_xhtml {
	my ( $self, $c, $text ) = @_;

	return '' unless $text;
   
    my $bbx = Parse::BBCode->new({
             %$WriteOff::View::HTML::BBCODE_CONFIG,
            linebreaks => 0,
        });

	$text = $bbx->render( $text );

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
