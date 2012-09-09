package WriteOff;
use Moose;
use namespace::autoclean;

use Catalyst::Runtime 5.80;
use Catalyst qw/
	-Debug
	ConfigLoader
	Static::Simple
	Unicode::Encoding
	
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

our $VERSION = '0.05';

__PACKAGE__->config(
	name => 'Write-off',
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
	scheduler => { time_zone => 'floating' },
	'Plugin::Session' => {
		flash_to_stash => 1,
	},
	validator => {
		plugins => [ qw/DBIC::Unique/ ],
		messages => {
			register => {
				username => {
					NOT_BLANK => 'Username is required',
					REGEX => 'Username contains invalid characters',
				},
				password => {
					NOT_BLANK => 'Password is required',
					LENGTH => 'Password is too short',
				},
				pass_confirm => {
					DUPLICATION => 'Passwords do not match',
				},
				email => {
					NOT_BLANK => 'Email is required',
					EMAIL_MX => 'Invalid email address',
				},
				captcha      => { EQUAL_TO => 'Invalid CAPTCHA' },
				unique_user  => { EQUAL_TO => 'Username already exists' },
				unique_email => { EQUAL_TO => 'A user with that email already exists' },
			},
			submit => {
				title     => { 
					NOT_BLANK   => 'Title is required',
					DBIC_UNIQUE => 'An item with that title already exists',
				},
				website   => { HTTP_URL      => 'Website is not a valid HTTP URL' },
				wordcount => { BETWEEN       => 'Story too long or too short' },
				related   => { NOT_EQUAL_TO  => 'Art title is required' },
				image     => { NOT_BLANK     => 'Image is required' },
				mimetype  => { IN_ARRAY      => 'Image not a valid type' },
				captcha   => { EQUAL_TO      => 'Invalid CAPTCHA' },
				sessionid => { IN_ARRAY      => 'Invalid session' },
				subs_allowed => { EQUAL_TO   => 'Submissions are closed' },
				prompt    => {
					NOT_BLANK   => 'Prompt is required',
					DBIC_UNIQUE => 'An identical prompt already exists',
				},
				blurb     => { LENGTH        => 'Blurb too long' },
				limit     => { LESS_THAN     => 'Limit exceeded' },
			},
		},
	},
	allowed_types => [qw:image/jpeg image/png image/gif:],
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
			img    => 4*1024*1024,
			prompt => 64,
		},
	},
	biz => {
		user => {
			regex => qr/\A[a-zA-Z0-9_]+\z/,
		},
		blurb => {
			max => 1024,
		}
	},
	elo_base => 1500,
	prompts_per_user => 5,
	interim => 60, #minutes
	bb => Parse::BBCode->new({
		tags => {
			b => '<strong>%{parse}s</strong>',
			i => '<em>%{parse}s</em>',
			u => '<span style="text-decoration: underline">%{parse}s</span>',
			url => '<a class="link" href="%{link}a">%{parse}s</a>',
			size => '<span style="font-size: %{size}apx;">%{parse}s</span>',
			color => '<span style="color: %{color}a;">%{parse}s</span>',
			center => '<span style="text-align: center">%{parse}s</span>',
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
				int $_[2] eq $_[2] && 
				8 <= $_[2] && $_[2] <= 72 ? 
				$_[2] : 16;
			},
			color => sub {
				$_[2] =~ /^#?[0-9a-zA-Z]+\z/ ? $_[2] : 'inherit';
			},
		},
	}),
	md => Text::Markdown->new,
	
	disable_component_resolution_regex_fallback => 1,
	enable_catalyst_header => 1,
);

__PACKAGE__->setup();

__PACKAGE__->schedule(
	at    => '0 * * * *',
	event => '/cron/clean_old_heats',
);

__PACKAGE__->schedule(
	at    => '* * * * *',
	event => '/cron/check_schedule',
);


=head1 NAME

WriteOff - Catalyst based application

=head1 SYNOPSIS

	script/writeoff_server.pl

=head1 DESCRIPTION

Web application for handling the logic required to run the write-off.

=head1 SEE ALSO

L<WriteOff::Controller::Root>, L<Catalyst>

=head1 AUTHOR

Cameron Thornton <cthor@cpan.org>

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
