package WriteOff;
use utf8;
use Moose;
use namespace::autoclean;
use 5.014;

use Catalyst::Runtime 5.80;
use Catalyst qw/
	ConfigLoader
	Static::Simple

	+WriteOff::Plugin::Auth
	+WriteOff::Plugin::Strings

	Session
	Session::Store::File
	Session::State::Cookie

	Cache

	RunAfterRequest

	FormValidator::Simple
	FillInForm
	Upload::MIME
/;

extends 'Catalyst';

require CHI;
require WriteOff::Log;
require WriteOff::Util;

our $VERSION = 'v0.65.0';

__PACKAGE__->config(
	name => 'Writeoff',
	encoding => 'UTF-8',

	DevEmail => 'cthor@cpan.org',

	#These should be configured on a per-deployment basis
	domain     => 'example.com',
	AdminName  => 'admin',
	AdminEmail => 'admin@example.com',

	default_view => 'TT',
	'View::TT' => {
		INCLUDE_PATH => [ __PACKAGE__->path_to('root', 'src' ) ],
	},
	'View::JSON' => {
		expose_stash => 'json',
	},
	'View::Epub' => {
		language => 'en',
	},
	'Plugin::Static::Simple' => {
		ignore_dirs => [ qw/src/ ],
		ignore_extensions => [],
	},
	'Plugin::Session' => {
		flash_to_stash => 1,
		expires => 365 * (60 * 60 * 24),
	},
	'Plugin::ConfigLoader' => {
		file => 'config.yml',
	},
    'Plugin::Cache' => {
        backend => {
            namespace => 'WriteOff',
            class => 'Cache::Memory',
            default_expires => '600 sec',
        },
    },

	timezone => 'UTC',
	validator => {
		plugins => [ 'DBIC::Unique', 'Trim' ],
		messages => {
			register => {
				username => {
					NOT_BLANK   => 'Username is required',
					REGEX       => 'Username contains invalid characters',
					DBIC_UNIQUE => 'Username is unavailable',
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
				passcheck    => { NOT_BLANK   => 'Current password is invalid' },
				pass_confirm => { DUPLICATION => 'Passwords do not match' },
				captcha      => { EQUAL_TO    => 'Invalid CAPTCHA' },
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
			alt    => 256,
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
		limit => 10,
		timer => 10, # minutes; cache expiration time
	},
	elo_base => 1500,
	prompts_per_user => 5,
	judge_distr_size => 5,
	interim => 60, #minutes
	use_google_analytics => 1,
	read_only => 0,
	pid => WriteOff::Util::token(),

	# How long it takes the average reader to review an entry:
	#
	#     work = wordcount/rate + offset
	#
	# i.e., it takes approximately 11 minutes + 1 per minute 200 words to
	# review a story.
	#
	# Threshold is how many minutes of reading per day a voter could be
	# expected to do, and determines how many entries make the finals. In
	# other words, this number is chosen so that those who are determined to
	# can reasonably read every entry in the finals.
	#
	# Voter is the fraction of the treshold that the *average* voter is
	# expected to be able to read per day.
	work => {
		rate => 200,
		offset => 11,
		threshold => 73,
		voter => 0.5,
	},

	limitCache => CHI->new(
		expires_in => '10s',
		driver => 'FastMmap',
		namespace => 'limit',
	),

	pageCache => CHI->new(
		expires_in => '7d',
		driver => 'FastMmap',
		namespace => 'page'
	),

	renderCache => CHI->new(
		expires_in => '10m',
		expires_variance => 0.2,
		driver => 'File',
		depth => 3,
		max_key_length => 8,
		namespace => 'render',
	),

	scoreCache => CHI->new(
		driver => 'File',
		max_key_length => 8,
		namespace => 'score',
	),

	disable_component_resolution_regex_fallback => 1,
	enable_catalyst_header => 1,
);

my $logger = WriteOff::Log->new;

if (!$ENV{CATALYST_DEBUG}) {
	$logger->path(__PACKAGE__->path_to('log'));
}

__PACKAGE__->log($logger);
__PACKAGE__->setup;

$ENV{TZ} = __PACKAGE__->config->{timezone};

if (defined __PACKAGE__->config->{now}) {
	$ENV{WRITEOFF_DATETIME} = __PACKAGE__->config->{now};
}

sub lang {
	my ($self, $lang) = @_;

	return $self->user->lang || 'en';
}

sub mailfrom {
	my ($self, $name, $user) = @_;

	$name //= $self->config->{name};
	$user //= 'noreply';

	sprintf "%s <%s@%s>", $name, $user, $self->config->{domain};
}

sub page {
	my $self = shift;
	my $page = shift // $self->req->param('page');
	my $cache = $self->config->{pageCache};

	my $key = $self->sessionid;
	if ($self->stash->{entry}) {
		$key .= '.entry.' . $self->stash->{entry}->id;
	}
	elsif ($self->stash->{event}) {
		$key .= '.event.' . $self->stash->{event}->id;
	}
	else {
		die "No page context";
	}

	if ($page && $page =~ /^([1-9][0-9]*)$/) {
		$page = int $1;
		$cache->set($key, $page);
		return $page;
	}
	else {
		return $cache->get($key) // 1;
	}
}

sub page_for {
	my ($self, $num) = @_;

	1 + int(($num - 1) / $self->page_size);
}

sub page_size {
	shift->user->page_size || 100;
}

BEGIN { *rows = \&page_size }

=head1 NAME

WriteOff - Writing contests with anonymous voting

=head1 SEE ALSO

L<WriteOff::Controller::Root>, L<Catalyst>

=head1 AUTHOR

Cameron Thornton E<lt>cthor@cpan.orgE<gt> (c) 2012

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
