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
	
	RunAfterRequest
	
	FormValidator::Simple 
	FillInForm
	Upload::MIME
/;
use Image::Magick;

extends 'Catalyst';

our $VERSION = 'v0.26.6';

__PACKAGE__->config(
	name => 'Write-off',
	
	DevEmail => 'cthor@cpan.org',
	
	#These should be configured on a per-deployment basis
	domain     => 'example.com',
	AdminName  => 'admin',
	AdminEmail => 'admin@example.com',
	
	default_view => 'HTML',
	'View::HTML' => { 
		INCLUDE_PATH => [ __PACKAGE__->path_to('root', 'src' ) ],
	},
	'View::JSON' => {
		expose_stash => 'json',
	},
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
				old          => { NOT_BLANK   => 'Old Password is invalid' },
				pass_confirm => { DUPLICATION => 'Passwords do not match' },
				captcha      => { NOT_BLANK   => 'Invalid CAPTCHA' },
			},
			submit => {
				title     => { 
					NOT_BLANK   => 'Title is required',
					DBIC_UNIQUE => 'An item with that title already exists',
				},
				author    => { DBIC_UNIQUE   => 'Author name is reserved by another user' },
				artist    => { DBIC_UNIQUE   => 'Artist name is reserved by another user' },
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
				rules     => { LENGTH        => 'Rules too long' },
				subs_left => { GREATER_THAN  => 'Submission limit exceeded' },
				
			},
			vote => {
				count   => { GREATER_THAN => 'You must vote on at least half of the entries' },
				ip      => { DBIC_UNIQUE  => 'You have already cast a vote' },
				user_id => { DBIC_UNIQUE  => 'You have already cast a vote' },
				captcha => { EQUAL_TO   => 'Invalid CAPTCHA' },
			},
			event => {
				start     => { DATETIME_FORMAT => 'Starting Date not a valid RFC3339 datetime' },
				wc_min    => { LESS_THAN => 'Wordcount Min > Max' },
				organiser => { NOT_DBIC_UNIQUE => 'Organiser not a real user' },
			},
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
			blurb  => 1024,
			rules  => 2048,
		},
	},
	biz => {
		user => {
			regex => qr{\A[a-zA-Z0-9_]+\z},
		},
		img => {
			size  => 2 * 1024 * 1024,
			types => [ qw:image/jpeg image/png image/gif: ],
		},
	},
	login => {
		limit => 5,
		timer => 5, #minutes
	},
	elo_base => 1500,
	prompts_per_user => 5,
	prelim_distr_size => 6,
	judge_distr_size => 5,
	interim => 60, #minutes
	use_google_analytics => 1,
	
	
	disable_component_resolution_regex_fallback => 1,
	enable_catalyst_header => 1,
);

__PACKAGE__->setup();

__PACKAGE__->log( Catalyst::Log->new( qw/info warn error fatal/ ) )
	if __PACKAGE__->debug;

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

sub timezones {
	my $self = @_;
	
	return qw/UTC/, grep {/\//} DateTime::TimeZone->all_names;
}

sub mailfrom {
	my( $self, $name, $user ) = @_;
	
	$name //= $self->config->{name};
	$user //= 'noreply';
	
	return sprintf "%s <%s@%s>", $name, $user, $self->config->{domain};
}

sub user_id {
	my $self = shift;
	
	return $self->user ? $self->user->get('id') : -1;
}

sub app_version {	
	return version->parse( $VERSION )->stringify;
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

Cameron Thornton E<lt>cthor@cpan.orgE<gt> (c) 2012

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
