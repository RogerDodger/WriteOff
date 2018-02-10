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
use Time::HiRes qw/gettimeofday tv_interval/;

extends 'Catalyst::View::TT';

__PACKAGE__->config(
	WRAPPER            => 'wrapper.tt',
	ENCODING           => 'utf-8',
	TEMPLATE_EXTENSION => '.tt',
	START_TAG          => quotemeta('{{'),
	END_TAG            => quotemeta('}}'),
	expose_methods     => [ qw/data_uri format_dt title_html spectrum/ ],
	render_die         => 1,
);

around template_vars => sub {
	my $orig = shift;
	my $self = shift;

	($self->$orig(@_), csrf_field => qq{<!-- GET csrf_field -->});
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

	ref => sub {
		return \$_[0];
	},

	ucfirst => sub {
		return ucfirst shift;
	},

	ordinal => sub {
		return $_ . (qw/th st nd rd/)[/(?<!1)([123])$/ ? $1 : 0] for int shift;
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

	map => [sub {
		my $key = shift;

		return sub {
			return [
				map {
					UNIVERSAL::can($_, $key) ? $_->$key : $_->{$key}
				} @{ $_[0] }
			]
		}
	}, 1],

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
	my $stash = $c->stash;
	$stash->{csrf_field} = qq{<input type="hidden" name="csrf_token" value="$token">};

	my $t0 = [gettimeofday];
	# Very light-weight post-processing language:
	#
	#   Supports GET, SET, and IF statements
	#   IF statements can only check the truthiness of a stash value
	#   SET statements are eval()d in this method's context
	#
	# This enables us to cache a rendered template that needs small changes on
	# a per user basis, such as showing the edit button only for the post's
	# owner.
	#
	# The most important feature is SPEED. General purpose templating systems
	# spend much needed time on accuracy and features. TT in particular spends
	# a large amount of time compiling templates, which isn't bad when your
	# templates don't change (since you can cache them), but for this use-case
	# is disastrous. A 100 page thread took 3s to compile and render, which is
	# far too much (even if subsequent renders are almost instant).
	#
	# SECURITY CONCERN: If user input can get here, then we're in big trouble.
	# I don't see any good reason for users to be able to inject HTML
	# comments, since that would surely mean an XSS vulnerability, but it
	# might be overlooked at some point in future that it can be escalated
	# into remote code execution.
	my $grammar = qr{
		<!--
		\s+
		(?| (GET) \s+ (\w+)
		  | (SET) \s+ (\w+) \s+ (.+?)
		  | (IF) \s+ (!?)(\w+)
		  | (END)
		  )
		\s+
		-->
	}ox;

	# First pass:
	#   Replace GET with equivalent stash value
	#   Evaluate SET statements
	#   Remove true IF blocks
	#   Replace false IF blocks with a <!-- REMOVE --> block
	#   Don't evaluate statements inside a false IF block
	# Second pass:
	#   Remove text enclosed by a <!-- REMOVE --> block
	my $state = 'default';
	my @if = ();

	$ret =~ s{$grammar}{
		my $val = '';

		if ($1 eq 'GET' && $state eq 'default') {
			$val = $stash->{$2} // '';
		}
		elsif ($1 eq 'SET' && $state eq 'default') {
			$stash->{$2} = eval $3;
		}
		elsif ($1 eq 'IF') {
			if ($state eq 'default') {
				if (!!$stash->{$3} ^ $2 eq '!') {
					push @if, 'true';
				}
				else {
					push @if, 'remove';
					$state = 'remove';
					$val = '<!-- REMOVE -->';
				}
			}
			else {
				push @if, 'null';
			}
		}
		elsif ($1 eq 'END') {
			die "END found without an associated IF\n" if @if == 0;

			if ('remove' eq pop @if) {
				$val = '<!-- END -->';
				$state = 'default';
			}
		}

		$val;
	}ge;

	$ret =~ s{<!-- REMOVE -->.+?<!-- END -->}{}sg;

	$c->log->debug('Post-processor took %ss', tv_interval $t0);

	$ret;
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
