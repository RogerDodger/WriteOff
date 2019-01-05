use utf8;
package WriteOff::Plugin::Captcha;

use Captcha::noCAPTCHA;
use Moose::Role;
use namespace::autoclean;

my $_cap;

after setup => sub {
	my $c = shift;

	$_cap = Captcha::noCAPTCHA->new({
		site_key => $c->config->{recaptcha}{pub_key},
		secret_key => $c->config->{recaptcha}{priv_key},
	});
};

sub captcha_html {
	my $c = shift;
	my $action = shift || 'register';
	my $key = $_cap->site_key;
	return qq{
		<script src="https://www.google.com/recaptcha/api.js"></script>
		<div class="g-recaptcha" data-sitekey="$key"></div>
	};
}

sub captcha_check {
	my $c = shift;

	$c->req->params->{captcha_ok} =
		int !!$_cap->verify($c->req->param('g-recaptcha-response'), $c->req->address);
}

1;
