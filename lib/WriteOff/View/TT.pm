package WriteOff::View::TT;
use utf8;
use 5.014;
use Moose;
use namespace::autoclean;
use Template::Stash;
use Template::Filters;
use Parse::BBCode;
use Text::Markdown;
use WriteOff::Util;
use WriteOff::DateTime;

extends 'Catalyst::View::TT';

__PACKAGE__->config(
	WRAPPER            => 'wrapper.tt',
	ENCODING           => 'utf-8',
	TEMPLATE_EXTENSION => '.tt',
	TIMER              => 1,
	expose_methods     => [ qw/format_dt title_html spectrum/ ],
	render_die         => 1,
);

our $BBCODE_CONFIG = {
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
};

__PACKAGE__->config->{FILTERS} = {
	markdown => sub {
		my $text = shift;
		$text = Text::Markdown->new->markdown($text);
		$text =~ s{</li>}{}g;
		return $text;
	},

	externallinks => sub {
		return shift =~ s{(<a [^>]+ >) ([^<]+) </a>}{$1<i class="fa fa-external-link"></i> $2</a>}rgx;
	},

	bbcode => [sub {
		my $c = shift;
		my $opt = shift // {};

		my $bb = Parse::BBCode->new($BBCODE_CONFIG);

		return sub {
			my $text = shift;
			$text = $bb->render($text);

			if ($opt->{xhtml}) {
				$text =~ s{<hr>}{<hr/>}g;
				$text =~ s{<br>}{<br/>}g;
			}

			return $text;
		};
	}, 1],

	simple_uri => \&WriteOff::Util::simple_uri,
};

$Template::Stash::SCALAR_OPS = {
	%$Template::Stash::SCALAR_OPS,

	ucfirst => sub {
		return ucfirst shift;
	},
};

$Template::Stash::LIST_OPS = {
	%$Template::Stash::LIST_OPS,

	join_serial => sub {
		my @list = @{+shift};

		return join ", ", @list if $#list < 2;

		my $last = pop @list;
		$list[-1] .= ", and $last";

		return join ", ", @list;
	},

	join_en => sub {
		join " – ", @{$_[0]};
	},

	sort_stdev => sub {
		return [ sort { $b->stdev <=> $a->stdev } @{ $_[0] } ]
	},

	map_username => sub {
		return [ map { $_->username } @{ $_[0] } ];
	},
};

sub format_dt {
	my ($self, $c, $dt, $fmt) = @_;

	return '' unless eval { $dt->set_time_zone('UTC')->isa('DateTime') };

	my $tz = $c->user->timezone || 'UTC';

	return sprintf '<time title="%s" datetime="%sZ">%s</time>',
		$dt->rfc2822,
		$dt->iso8601,
		do {
			my $local = $dt->clone->set_time_zone($tz);
			defined $fmt ? $local->strftime($fmt) : $local->rfc2822;
		};
}

sub spectrum {
	my ($self, $c, $left, $right, $pos) = @_;

	# Assuming RGB triplets;
	my @left = map { hex $_ x 2 } split //, $left;
	my @right = map { hex $_ x 2 } split //, $right;

	my @diff = map { $right[$_] - $left[$_] } 0..2;

	return join '', map {
		sprintf "%02x", int($left[$_] + $diff[$_] * $pos)
	} 0..2;
}

sub title_html {
	my ($self, $c) = @_;
	my $title = $c->stash->{title};
	$title = join " &#8250; ",
	           map { Template::Filters::html_filter($_) }
	             ref $title eq 'ARRAY' ? reverse @$title : $title || ();
	return join " &#x2022; ", $title || (), $c->config->{name};
}

1;
