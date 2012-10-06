package WriteOff::View::HTML;
use Moose;
use namespace::autoclean;
use Template::Stash;
use Parse::BBCode;
use Text::Markdown;

extends 'Catalyst::View::TT';

__PACKAGE__->config(
	WRAPPER            => 'wrapper.tt',
	ENCODING           => 'utf-8',
	TEMPLATE_EXTENSION => '.tt',
	TIMER              => 1,
	expose_methods     => [ qw/format_dt md_render bb_render prompt_subs_left/ ],
	render_die         => 1,
);

$Template::Stash::SCALAR_OPS->{minus} = sub { 
	return $_[0] - $_[1];
};

$Template::Stash::LIST_OPS->{join_serial} = sub {
	my @list = @{+shift};
	
	return join ", ", @list if $#list < 2;
	
	my $last = pop @list;
	$list[-1] .= ", and $last";
	
	return join ", ", @list;
};

$Template::Stash::LIST_OPS->{map_username} = sub {
	return [ map { $_->username } @{$_[0]} ];
};

my $RFC2822 = '%a, %d %b %Y %T %Z';

sub format_dt {
	my( $self, $c, $dt, $fmt ) = @_;
	
	return '' unless eval { $dt->set_time_zone('UTC')->isa('DateTime') };
	
	my $tz = $c->user ? $c->user->get('timezone') : 'UTC';
	
	return sprintf '<time title="%s" datetime="%sZ">%s</time>',
	$dt->strftime($RFC2822), 
	$dt->iso8601, 
	$dt->set_time_zone($tz)->strftime($fmt // $RFC2822);
}

my $bb = Parse::BBCode->new({
	tags => {
		b => '<strong>%{parse}s</strong>',
		i => '<em>%{parse}s</em>',
		u => '<span style="text-decoration: underline">%{parse}s</span>',
		url => '<a class="link new-window" href="%{link}a">%{parse}s</a>',
		size => '<span style="font-size: %{size}apx;">%{parse}s</span>',
		color => '<span style="color: %{color}a;">%{parse}s</span>',
		center => '<div style="text-align: center">%{parse}s</div>',
		smcaps => '<span style="font-variant: small-caps">%{parse}s</span>',
		quote => {
			class => 'block',
			output => "<br>\n<blockquote>%{parse}s</blockquote>\n",
		},
		hr => {
			class => 'block',
			output => "<br>\n<hr />\n",
			single => 1,
		},
	},
	escapes => {
		Parse::BBCode::HTML->default_escapes,
		size => sub {
			$_[2] !~ /\D/ && 
			8 <= $_[2] && $_[2] <= 72 ? 
			$_[2] : 16;
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
	$text =~ s{</div>\s*<br>}{</div>}g;
	$text =~ s{<br>}{<br />}g;
	
	return $text;
}

sub md_render {
	my ( $self, $c, $text ) = @_;
	
	return '' unless $text;
	
	$text = Text::Markdown->new->markdown( $text );
	$text =~ s{<a (.+?)>}{<a class="link new-window" $1>}g;
	
	return $text;
}

sub prompt_subs_left {
	my ( $self, $c ) = @_;
	
	return 0 unless $c->stash->{event} && $c->user;
	
	my $rs = $c->stash->{event}->prompts->search({ user_id => $c->user->id });
	
	return $c->config->{prompts_per_user} -	$rs->count;
		
}

1;
