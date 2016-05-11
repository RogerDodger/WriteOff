use utf8;
package WriteOff::View::Email;

use strict;
use warnings;
use base 'Catalyst::View';

use Email::MIME;
use Email::Sender::Simple ();
use Text::Wrap ();

sub process {
	my ($self, $c) = @_;

	$c->stash->{subject} = $c->stash->{email}{subject} // 'No subject';

	my $html = $c->view('TT')->render($c, $c->stash->{email}{template});
	$c->stash->{wrapper} = 'wrapper/none.tt';
	my $plain = $c->view('TT')->render($c, $c->stash->{email}{template});

	if (!$html || !$plain) {
		die 'Failed to render template: ' . $c->stash->{email}{template} . "\n";
	}

	for ($html, $plain) {
		# Trim comments and trailing space from email body
		s/<!--.+?-->//gs;
		s/^\s+|\s+$//g;
	}

	# Re-wrap paragraphs (templates are wrapped, but output won't line up properly)
	$plain =~ s/(?<!\n)\n(?!\n)/ /g;
	$plain = Text::Wrap::wrap("", "", $plain);

	my $email = Email::MIME->create(
		header => [
			From    => $c->mailfrom,
			Subject => $c->stash->{subject},
		],
		parts => [
			Email::MIME->create(
				body => $plain,
				attributes => {
					content_type => 'text/plain',
					charset => 'utf-8',
					encoding => 'quoted-printable',
				}
			),
			Email::MIME->create(
				body => $html,
				attributes => {
					content_type => 'text/html',
					charset => 'utf-8',
					encoding => 'quoted-printable',
				}
			),
		],
	);

	if ($c->stash->{email}{to}) {
		$email->header_set(To => $c->stash->{email}{to});
		Email::Sender::Simple->send($email);
	}

	if ($c->stash->{email}{users}) {
		for my $user ($c->stash->{email}{users}->all) {
			$email->header_set(To => sprintf "%s <%s>", $user->name, $user->email);
			Email::Sender::Simple->send($email);
		}
	}
}

1;
