package WriteOff::View::TT;
use utf8;
use 5.014;

use JSON;
use Moose;
use namespace::autoclean;
use Template::Stash;
use Template::Filters;
use Template::AutoFilter::Parser;
use Parse::BBCode;
use Text::Markdown;
use WriteOff::Util;
use WriteOff::DateTime;
use URI;

extends 'Catalyst::View::TT';

__PACKAGE__->config(
	WRAPPER            => 'wrapper.tt',
	ENCODING           => 'utf-8',
	TEMPLATE_EXTENSION => '.tt',
	START_TAG          => quotemeta('{{'),
	END_TAG            => quotemeta('}}'),
	TIMER              => 1,
	expose_methods     => [ qw/csrf_field data_uri format_dt title_html spectrum/ ],
	render_die         => 1,
);

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

		return sub {
			my $text = shift;
			$text = WriteOff::Util::bbcode($text);

			if ($opt->{xhtml}) {
				$text =~ s{<hr>}{<hr/>}g;
				$text =~ s{<br>}{<br/>}g;
			}

			return $text;
		};
	}, 1],

	simple_uri => \&WriteOff::Util::simple_uri,
	none => sub { $_[0] },
};

__PACKAGE__->config->{PARSER} = Template::AutoFilter::Parser->new(__PACKAGE__->config);

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

	json => sub {
		return encode_json $_[0];
	},
};

$Template::Stash::HASH_OPS = {
	%$Template::Stash::HASH_OPS,

	json => sub {
		return encode_json $_[0];
	},
};

sub render {
	my $self = shift;
	my ($c, $template, $args) = @_;
	my $ret = $self->next::method(@_);

	my $token = $c->csrf_token;
	$ret =~ s{<csrf-field/>}{<input type="hidden" name="csrf_token" value="$token">}g;

	$ret;
}

sub csrf_field {
	qq{<csrf-field/>};
}

sub data_uri {
	my ($self, $c, $path) = @_;

	my $ext = $path =~ /\.(\w+)$/ ? $1 : 'png';
	open my $fh, "<", $c->path_to($path);
	binmode $fh;

	my $uri = URI->new('data:');
	$uri->media_type("image/$ext");
	$uri->data(do { local $/ = <$fh> });

	close $fh;

	if ("$uri" =~ /^(.+;base64,)(.+)$/) {
		my $meta = $1;
		my $data = $2;

		# Wrap the data to 80 characters -- long data URIs were causing
		# problems with the DKIM signing of emails because the lines were too
		# long, resulting in postfix truncating the message after signing
		# (SMTP expects lines < 1000 chars), and therefore making the
		# signature invalid
		for (my $i = 80; $i <= length $data; $i += 81) {
			substr($data, $i, 0, "\n");
		}

		return "$meta\n$data\n";
	}

	"$uri";
}

sub format_dt {
	my ($self, $c, $dt, $fmt, $tz) = @_;

	return '' unless eval { $dt->set_time_zone('UTC')->isa('DateTime') };

	$tz //= $c->user->timezone || 'UTC';

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
