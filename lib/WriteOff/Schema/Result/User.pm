use utf8;
package WriteOff::Schema::Result::User;

use strict;
use warnings;
use base "WriteOff::Schema::Result";

use Bytes::Random::Secure qw/random_bytes/;
use Crypt::Eksblowfish::Bcrypt qw/bcrypt en_base64/;
use Digest::MD5 qw/md5_hex/;
use MIME::Base64 2.21 qw/decode_base64/;
use WriteOff::Util;

__PACKAGE__->load_components(qw/FilterColumn/);

__PACKAGE__->table("users");

__PACKAGE__->add_columns(
	"id",
	{ data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
	"active_artist_id",
	{ data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
	"name",
	{ data_type => "text", is_nullable => 0 },
	"name_canonical",
	{ data_type => "text", is_nullable => 0 },
	"password",
	{ data_type => "text", is_nullable => 0 },
	"email",
	{ data_type => "text", is_nullable => 1 },
	"email_canonical",
	{ data_type => "text", is_nullable => 1 },
	"admin",
	{ data_type => "bit", is_nullable => 0, default_value => 0 },
	"verified",
	{ data_type => "integer", default_value => 0, is_nullable => 0 },
	"mailme",
	{ data_type => "integer", default_value => 0, is_nullable => 0 },
	"created",
	{ data_type => "timestamp", is_nullable => 1 },
	"updated",
	{ data_type => "timestamp", is_nullable => 1 },
);

__PACKAGE__->set_primary_key("id");

__PACKAGE__->add_unique_constraint("email_unique", ["email_canonical"]);
__PACKAGE__->add_unique_constraint("name_unique", ["name_canonical"]);

__PACKAGE__->has_many("artists", "WriteOff::Schema::Result::Artist", "user_id");
__PACKAGE__->has_many("ballots", "WriteOff::Schema::Result::Ballot", "user_id");
__PACKAGE__->has_many("prompts", "WriteOff::Schema::Result::Prompt", "user_id");
__PACKAGE__->has_many("tokens", "WriteOff::Schema::Result::Token", "user_id");
__PACKAGE__->has_many("prompt_votes", "WriteOff::Schema::Result::PromptVote", "user_id");
__PACKAGE__->belongs_to("active_artist", "WriteOff::Schema::Result::Artist", "active_artist_id");
__PACKAGE__->has_many("user_events", "WriteOff::Schema::Result::UserEvent", "user_id");

__PACKAGE__->mk_group_accessors(
	column => 'role',
	column => 'prompt_skill',
	column => 'hugbox_score',
);

__PACKAGE__->filter_column('password', {
	filter_to_storage => sub {
		my ($obj, $plain) = @_;

		my $cost = '10';
		my $salt = en_base64 random_bytes 16;
		my $settings = join '$', '$2', $cost, $salt;

		bcrypt($plain, $settings);
	},
});

sub check_password {
	my ($self, $plain) = @_;

	# Old passwords on SHA-1
	if ($self->password =~ /^\{SSHA\}(.+)$/) {
		my $bits = decode_base64 $1;

		my $salt = substr $bits, 20;
		my $hash = substr $bits, 0, 20;

		if (Digest->new('SHA1')->add($plain, $salt)->digest eq $hash) {
			# Update the password to use bcrypt now that we have the plaintext
			# in memory
			$self->update({ password => $plain });
			return 1;
		}
		else {
			return 0;
		}
	}
	else {
		return bcrypt($plain, $self->password) eq $self->password;
	}
}

sub lang {
	'en';
}

sub username {
	return shift->name;
}

sub username_and_email {
	my $self = shift;

	return sprintf "%s <%s>", $self->username, $self->email;
}

sub last_author {
	my $self = shift;
	my $last_story = $self->storys->order_by({ -desc => 'updated' })->first;
	return $last_story ? $last_story->artist->name : undef;
}

sub last_artist {
	my $self = shift;
	my $last_image = $self->images->order_by({ -desc => 'updated' })->first;
	return $last_image ? $last_image->artist->name : undef;
}

sub primary_artist {
	my $self = shift;
	my $artists = $self->result_source->schema->resultset('Artist');

	my %freq;
	$freq{$_->artist_id}++ for $self->storys, $self->images;

	if (!%freq) {
		# No artist, make one
		my $artist = $artists->find_or_new({ name => $self->username });

		# Shouldn't need to do this -- create artist when user is created
		if (!$artist->in_storage) {
			$artist->user_id($self->id);
			$artist->score(0);
			$artist->insert;
		}

		return $artist;
	}
	else {
		my $max = [0, 0];
		while (my ($aid, $count) = each %freq) {
			$max = [$aid, $count] if $count > $max->[1];
		}
		return $artists->find($max->[0]);
	}
}

BEGIN { *is_admin = \&admin; }

sub find_token {
	my ($self, $type, $value) = @_;

	my $tokens = $self->tokens;

	return $tokens->search({
		type => $type,
		value => $value,
		expires => { '>' => $tokens->format_datetime(DateTime->now) },
	})->single;
}

sub new_token {
	my ($self, $type, $address) = @_;
	my %token = (
		address => $address,
		expires => DateTime->now->add(days => 1),
		value   => WriteOff::Util::token(),
	);

	if (my $row = $self->tokens->find($self->id, $type)) {
		$row->update(\%token);
		return $row;
	}
	else {
		$token{type} = $type;
		return $self->create_related('tokens', \%token);
	}
}

sub new_password {
	my $self = shift;

	my $pass = join q{}, map { ('a'..'z')[rand 26] } 0..4;

	$self->update({ password => $pass });

	return $pass;
}

sub offset {
	(hex substr md5_hex(shift->id), 0, 8) / (1 << 32);
}

sub organises {
	my ($self, $event) = @_;

	return $event->is_organised_by($self);
}

sub entrys {
	my $self = shift;

	$self->result_source->schema->resultset('Entry')->search({ user_id => $self->id }, { join => 'artist' });
}

sub storys {
	shift->entrys->search({ story_id => { "!=" => undef } });
}

sub images {
	shift->entrys->search({ image_id => { "!=" => undef } });
}

1;
