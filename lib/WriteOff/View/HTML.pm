package WriteOff::View::HTML;
use utf8;
use Moose;
use namespace::autoclean;
use Template::Stash;
use Parse::BBCode;
use Text::Markdown;
use WriteOff::Helpers;

extends 'Catalyst::View::TT';

__PACKAGE__->config(
	WRAPPER            => 'wrapper.tt',
	ENCODING           => 'utf-8',
	TEMPLATE_EXTENSION => '.tt',
	TIMER              => 1,
	expose_methods     => [ qw/
		format_dt md_render bb_render medal_for head_title simple_uri
	/ ],
	render_die         => 1,
);

$Template::Stash::LIST_OPS->{join_serial} = sub {
	my @list = @{+shift};
	
	return join ", ", @list if $#list < 2;
	
	my $last = pop @list;
	$list[-1] .= ", and $last";
	
	return join ", ", @list;
};

$Template::Stash::LIST_OPS->{join_en} = sub {
	join " – ", @{$_[0]};
};

$Template::Stash::LIST_OPS->{sort_stdev} = sub {
	return [ sort { $b->stdev <=> $a->stdev } @{ $_[0] } ]
};

$Template::Stash::LIST_OPS->{map_username} = sub {
	return [ map { $_->username } @{ $_[0] } ];
};

my $RFC2822 = '%a, %d %b %Y %T %Z';

sub simple_uri {
	my $self = shift;
	my $c = shift;
	return WriteOff::Helpers::simple_uri(@_);
}

sub format_dt {
	my( $self, $c, $dt, $fmt ) = @_;
	
	return '' unless eval { $dt->set_time_zone('UTC')->isa('DateTime') };
	
	my $tz = $c->user ? $c->user->get('timezone') : 'UTC';
	
	return sprintf '<time title="%s" datetime="%sZ">%s</time>',
	$dt->strftime($RFC2822), 
	$dt->iso8601, 
	$dt->set_time_zone($tz)->strftime($fmt // $RFC2822);
}

sub head_title {
	my( $self, $c ) = @_;
	
	my $title = $c->stash->{title};
	
	return 
		join " – ",
		map { Template::Filters::html_filter($_) } 
		( ref $title eq 'ARRAY' ? @$title : $title || () ), $c->config->{name};
}

my $bb = Parse::BBCode->new({
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
});

sub bb_render {
	my ( $self, $c, $text ) = @_;
	
	return '' unless $text;
	
	$text = $bb->render( $text );

	# Remove line breaks that immediately follow blocks
	for my $block ( '<hr>', '</blockquote>', '</div>' ) {
		my $e = quotemeta $block;
		$text =~ s/$e\K\s*?<br>//g;
	}
	
	return $text;
}

sub md_render {
	my ( $self, $c, $text ) = @_;
	
	return '' unless $text;
	
	$text = Template::Filters::html_filter( $text );
	$text = Text::Markdown->new->markdown( $text );
	$text =~ s{<a (.+?)>}{<a class="link new-tab" $1>}g;
	
	return $text;
}

sub medal_for {
	my( $self, $c, $pos ) = @_;
	
	return $c->model('DB::Award')->medal_for( $pos );
}

1;
