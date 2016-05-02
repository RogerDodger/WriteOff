use utf8;
package WriteOff::View::Email::Bulk;

use strict;
use warnings;
use base 'Catalyst::View';

use Email::Simple;
use Email::Sender::Simple;

sub process {
	my ($self, $c) = @_;

	$c->stash->{bulk} = 1;

	my $body = $c->view('TT')->render($c, $c->stash->{email}{template})
		or die 'Failed to render template: ' . $c->stash->{email}{template} . "\n";

	my $email = Email::Simple->create(
		header => [
			From           => $c->mailfrom,
			Subject        => $c->stash->{email}{subject} // 'No subject',
			"Content-type" => q{text/html; charset="utf8"},
		],
		body => $body,
	);

	for my $user ($c->stash->{email}{users}->all) {
		$email->header_set(To => sprintf "%s <%s>", $user->name, $user->email);
		Email::Sender::Simple->send($email);
	}
}

1;
