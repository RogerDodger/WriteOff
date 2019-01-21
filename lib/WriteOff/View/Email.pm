use utf8;
package WriteOff::View::Email;

use strict;
use warnings;
use base 'Catalyst::View';

use CSS::Inliner;
use Email::MIME;
use Email::Sender::Simple ();
use Text::Wrap ();

sub process {
	my ($self, $c) = @_;

	$c->stash->{subject} = $c->stash->{email}{subject} // 'No subject';

	# Assets in some email clients won't work with a relative URI scheme, so
	# we need to specify one to use in emails. Default to HTTP.
	$c->req->base->scheme($c->config->{https} ? 'https' : 'http');

	my $html = $c->view('TT')->render($c, $c->stash->{email}{template});
	my $plain = do {
		local $c->stash->{wrapper} = 'wrapper/none.tt';
		$c->view('TT')->render($c, $c->stash->{email}{template});
	};

	# Resetting scheme to its original value
	$c->req->base->scheme('');

	if (!$html || !$plain) {
		die 'Failed to render template: ' . $c->stash->{email}{template} . "\n";
	}

	for ($html, $plain) {
		# Trim comments and trailing space from email body
		s/<!--.+?-->//gs;
		s/^\s+|\s+$//g;
	}

	# Inline the CSS tags because GMail and Hotmail are butts
	my $inliner = CSS::Inliner->new;
	$inliner->read({ html => $html });
	$html = $inliner->inlinify;

	# Re-wrap paragraphs (templates are wrapped, but output won't line up properly)
	$plain =~ s/(?<!\n)\n(?!\n)/ /g;
	$plain = Text::Wrap::wrap("", "", $plain);

	if ($c->debug) {
		if ($c->stash->{email}{users}) {
			$html =~ s{</html>}{
				my $n = $c->stash->{email}{users}->count;
				"<p>$n Recipients</p></html>"
			}xe;
		}
		return $c->res->body($html);
	}

	my $email = Email::MIME->create(
		header => [
			From    => $c->mailfrom,
			Subject => $c->stash->{subject},
		],
		attributes => {
			content_type => 'multipart/alternative',
		},
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
