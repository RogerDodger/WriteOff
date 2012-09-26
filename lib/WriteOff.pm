package WriteOff;
use utf8;
use Moose;
use namespace::autoclean;
use 5.014;

use Catalyst::Runtime 5.80;
use Catalyst qw/
	ConfigLoader
	Static::Simple
	Unicode::Encoding
	
	Log::Handler
	
	Scheduler
	
	Authentication
	Authorization::Roles
	
	Session
	Session::Store::File
	Session::State::Cookie
	
	FormValidator::Simple 
	FillInForm
	Upload::MIME
/;
use Image::Magick;
use Parse::BBCode;
use Text::Markdown;

extends 'Catalyst';

our $VERSION = '0.13';

__PACKAGE__->config(
	name => 'Write-off',
	
	#These should be configured on a per-deployment basis
	domain     => 'example.com',
	AdminName  => 'admin',
	AdminEmail => 'admin@example.com',
	
	default_view => 'HTML',
	'View::HTML'         => { INCLUDE_PATH => [ __PACKAGE__->path_to('root', 'src' ) ] },
	'View::HTML::NoWrap' => { INCLUDE_PATH => [ __PACKAGE__->path_to('root', 'src' ) ] },
	'Plugin::Authentication' => {
		default => {
			class         => 'SimpleDB',
			user_model    => 'DB::User',
			password_type => 'self_check',
		},
	},
	'Plugin::Session' => {
		flash_to_stash => 1,
		expires => 365 * (60 * 60 * 24),
	},
	'Log::Handler' => {
		filename => __PACKAGE__->path_to('writeoff.log')->stringify,
		fileopen => 1,
		mode     => 'append',
		newline  => 1,
	},
	timezone => 'UTC',
	scheduler => { time_zone => 'floating' },
	validator => {
		plugins => [ 'DBIC::Unique', 'Trim' ],
		messages => {
			register => {
				username => {
					NOT_BLANK   => 'Username is required',
					REGEX       => 'Username contains invalid characters',
					DBIC_UNIQUE => 'Username exists',
				},
				password => {
					NOT_BLANK => 'Password is required',
					LENGTH    => 'Password is too short',
				},
				email => {
					NOT_BLANK   => 'Email is required',
					EMAIL_MX    => 'Invalid email address',
					DBIC_UNIQUE => 'A user with that email already exists',
				},
				old_password => { 
					NOT_BLANK => 'Old Password is required',
					EQUAL_TO  => 'Old Password is invalid',
				},
				pass_confirm => { DUPLICATION => 'Passwords do not match' },
				captcha      => { EQUAL_TO => 'Invalid CAPTCHA' },
			},
			submit => {
				title     => { 
					NOT_BLANK   => 'Title is required',
					DBIC_UNIQUE => 'An item with that title already exists',
				},
				image_id  => { NOT_BLANK     => 'Art Title is required' },
				website   => { HTTP_URL      => 'Website is not a valid HTTP URL' },
				wordcount => { BETWEEN       => 'Wordcount too high or too low' },
				story     => { NOT_BLANK     => 'Story is required' },
				image     => { NOT_BLANK     => 'Image is required' },
				mimetype  => { IN_ARRAY      => 'Image not a valid type' },
				captcha   => { EQUAL_TO      => 'Invalid CAPTCHA' },
				sessionid => { IN_ARRAY      => 'Invalid session' },
				prompt    => {
					NOT_BLANK   => 'Prompt is required',
					DBIC_UNIQUE => 'An identical prompt already exists',
				},
				blurb     => { LENGTH        => 'Blurb too long' },
				count     => { LESS_THAN     => 'Submission limit exceeded' },
				
			},
			vote => {
				count => { GREATER_THAN => 'You must vote on at least half of the entries' },
				ip    => { DBIC_UNIQUE  => 'You have already cast a vote' },
				user  => { DBIC_UNIQUE  => 'You have already cast a vote' },
				captcha => { EQUAL_TO   => 'Invalid CAPTCHA' },
			}
		},
	},
	len => {
		min => {
			pass => 5,
		},
		max => {
			user   => 32,
			pass   => 64,
			email  => 256,
			title  => 64,
			url    => 256,
			prompt => 64,
		},
	},
	biz => {
		user => {
			regex => qr{\A[a-zA-Z0-9_]+\z},
		},
		blurb => {
			max => 1024,
		},
		img => {
			size  => 4 * 1024 * 1024,
			types => [ qw:image/jpeg image/png image/gif: ],
		},
	},
	login => {
		limit => 5,
		timer => 5, #minutes
	},
	elo_base => 1500,
	prompts_per_user => 5,
	interim => 60, #minutes
	awards => {
		gold => {
			path => '/static/images/awards/medal_gold.png',
			alt  => 'Gold medal',
		},
		silver => {
			path => '/static/images/awards/medal_silver.png',
			alt  => 'Silver medal',
		},
		bronze => {
			path => '/static/images/awards/medal_bronze.png',
			alt  => 'Bronze medal',
		},
		ribbon => {
			path => '/static/images/awards/ribbon.gif',
			alt  => 'Participation ribbon',
		},
	},
	
	disable_component_resolution_regex_fallback => 1,
	enable_catalyst_header => 1,
);

__PACKAGE__->setup();

$ENV{TZ} = __PACKAGE__->config->{timezone};

__PACKAGE__->schedule(
	at    => '0 * * * *',
	event => '/cron/cleanup',
);

__PACKAGE__->schedule(
	at    => '* * * * *',
	event => '/cron/check_schedule',
);

sub wordcount {
	my ( $self, $str ) = @_;
	return scalar split /\s+/, $str;
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
	my ( $self, $text ) = @_;
	
	return '' unless $text;
	
	$text = $bb->render( $text );
	$text =~ s{</div>\s*<br>}{</div>}g;
	$text =~ s{<br>}{<br />}g;
	
	return $text;
}

sub md_render {
	my ( $self, $text ) = @_;
	
	return '' unless $text;
	
	$text = Text::Markdown->new->markdown( $text );
	$text =~ s{<a (.+?)>}{<a class="link new-window" $1>}g;
	
	return $text;
}

=head1 NAME

WriteOff - Catalyst based application

=head1 SYNOPSIS

	script/writeoff_server.pl

=head1 DESCRIPTION

Web application for handling the logic required to run a write-off event.

=head1 SEE ALSO

L<WriteOff::Controller::Root>, L<Catalyst>

=head1 AUTHOR

Cameron Thornton E<lt>cthor@cpan.orgE<gt>

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
