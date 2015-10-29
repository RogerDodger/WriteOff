package WriteOff::Controller::Root;
use Moose;
use namespace::autoclean;
require WriteOff::DateTime;

no warnings "uninitialized";

BEGIN { extends 'Catalyst::Controller' }
with 'Catalyst::TraitFor::Controller::reCAPTCHA';

__PACKAGE__->config(namespace => '');

=head1 NAME

WriteOff::Controller::Root - Root Controller for WriteOff

=head1 METHODS

=head2 auto

Logs the request.

Detaches to index if the request is POST with a differing origin.

=cut

sub auto :Private {
	my ( $self, $c ) = @_;

	if ($c->req->uri->path =~ m{^/static/(style|js)/writeoff-.+(css|js)$}) {
		$c->serve_static_file("root/static/$1/writeoff.$2");
		$c->log->abort(1);
		return 0;
	}

	$c->stash(
		now        => WriteOff::DateTime->now,
		news       => $c->model('DB::News')->order_by({ -desc => 'created' }),
		title      => [],
		editor     => $c->user->admin,
		format     => scalar($c->req->param('format')) || 'html',
		csrf_token => Digest->new('Whirlpool')->add($c->sessionid)->b64digest,
		messages   => [],
	);

	my $so = $c->req->uri->host eq eval { URI->new( $c->req->referer )->host };

	$c->log->_log("access", "[%s] %s (%s) - %s" . ( $so ? "" : " - %s" ),
		$c->req->method,
		$c->req->address,
		( $c->user ? $c->user->username : 'guest' ),
		$c->req->uri->path,
		$c->req->referer || 'no referer',
	);

	if ($c->req->method eq 'POST') {
		$c->req->{parameters} = {} if $c->config->{read_only};
		$c->detach('index') if !$so;
	}

	if ($c->req->header('x-requested-with') eq 'XMLHttpRequest') {
		$c->stash->{ajax} = 1;
		$c->stash->{wrapper} = 'wrapper/bare.tt';
	}

	if ($c->config->{read_only}) {
		push $c->stash->{messages}, 'The site is currently in read-only mode.';
	}

	1;
}

=head2 index

Lists all active events.

=cut

sub index :Path :Args(0) {
	my ( $self, $c ) = @_;

	$c->stash->{events} = $c->model('DB::Event')->active;

	push $c->stash->{title}, 'Events';
	$c->stash->{template} = 'event/list.tt';
}

=head2 archive

Lists all old events.

=cut

sub archive :Local :Args(0) {
	my ( $self, $c ) = @_;

	$c->stash->{events} = $c->model('DB::Event')->old;

	push $c->stash->{title}, 'Event Archive';
	$c->stash->{template} = 'event/list.tt';
}

=head2 faq

Frequently Asked Questions page

=cut

sub faq :Local :Args(0) {
	my ( $self, $c ) = @_;

	$c->stash->{document} = $c->document('faq');

	push $c->stash->{title}, 'FAQ';
	$c->stash->{template} = 'root/document.tt';
}

=head2 default

Standard 404 error page

=cut

sub default :Path {
	my ( $self, $c ) = @_;

	push $c->stash->{title}, 'File Not Found' ;
	$c->stash->{template} = 'root/404.tt';
	$c->res->status(404);
}

=head2 forbidden

Standard 403 page

=cut

sub forbidden :Private {
	my ( $self, $c, $msg ) = @_;

	$c->stash->{forbidden_msg} = $msg // 'Access denied';

	push $c->stash->{title}, 'Forbidden';
	$c->stash->{template} = 'root/403.tt';
	$c->res->status(403);
}

=head2 error

Error page

=cut

sub error :Private {
	my ( $self, $c, $msg ) = @_;

	if (!defined $c->stash->{error}) {
		$c->stash->{error} = $msg // 'Something went wrong';
	}

	if ($c->res->status == 200) {
		$c->res->status(400);
	}

	push $c->stash->{title}, 'Error';
	$c->stash->{template} = 'root/error.tt';
}

=head2 tos

Terms of Service page

=cut

sub tos :Local :Args(0) {
	my ( $self, $c ) = @_;

	$c->stash->{document} = $c->document('tos');

	push $c->stash->{title}, $c->stash->{document}{title};
	$c->stash->{template} = 'root/document.tt';
}

=head2 rights

Content rights page

=cut

sub rights :Local :Args(0) {
	my ($self, $c) = @_;

	$c->stash->{document} = $c->document('rights');

	push $c->stash->{title}, $c->stash->{document}{title};
	$c->stash->{template} = 'root/document.tt';
}

=head2 style

Formatting and style guide

=cut

sub style :Local :Args(0) {
	my ($self, $c) = @_;

	$c->stash->{document} = $c->document('style');

	push $c->stash->{title}, $c->stash->{document}{title};
	$c->stash->{template} = 'root/document.tt';
}

=head2 contact

Allow users to contact the admin or developer.

=cut

sub contact :Local :Args(0) {
	my ( $self, $c ) = @_;

	if( $c->user ) {

		$c->stash->{fillform}{from} = $c->user->username_and_email;

		my $staff = $c->stash->{staff} = [
			sprintf( "%s <%s>", 'Admin', $c->config->{AdminEmail} ),
			sprintf( "%s <%s>", 'Developer', $c->config->{DevEmail} ),
		];

		my $subjects = $c->stash->{subjects} = [
			'Event Idea',
			'Feature Request',
			'Bug Report',
			'Rule Breakers',
			'Other',
		];

		if( $c->req->method eq 'POST' ) {

			$c->form(
				to => [ 'NOT_BLANK', [ 'IN_ARRAY', @$staff ] ],
				subject => [ 'NOT_BLANK', [ 'IN_ARRAY', @$subjects ] ],
				message => [ 'NOT_BLANK' ],
			);

			$c->forward('send_contact_email') if !$c->form->has_error;
		}
	}

	push $c->stash->{title}, 'Contact Us';
	$c->stash->{template} = 'root/contact.tt';
}

sub send_contact_email :Private {
	my ( $self, $c ) = @_;

	for my $recipient ($c->form->valid('to'), $c->user->username_and_email) {
		$c->stash->{email} = {
			to           => $recipient,
			from         => $c->mailfrom,
			subject      => $c->config->{name} . " - Contact Us - " . $c->form->valid('subject'),
			template     => 'email/contact.tt',
			content_type => 'text/html',
		};
		$c->stash->{recipient} = $c->stash->{email}{to};

		$c->log->info( "Contact email sent to $recipient" );

		$c->forward( $c->view('Email::Template') );

		if (scalar @{ $c->error }) {
			$c->log->error($_) for @{ $c->error };
			$c->error(0);
		}
	}

	$c->stash->{status_msg} = 'Email sent successfully';
}

=head2 robots

Dynamically generated robots.txt

=cut

sub robots :Path('/robots.txt') :Args(0) {
	my ($self, $c) = @_;

	my $storys = $c->model('DB::Story')->search(
		{ indexed => { "!=" => 1 } },
		{ columns => [ qw/id title/ ] },
	);

	my $body = "User-agent: *\n";
	while (my $story = $storys->next) {
		$body .= "Disallow: /fic/" . $story->id_uri . "\n";
	}

	$c->res->body($body);
	$c->res->content_type('text/plain; charset=utf-8');
}

=head2 assert_admin

Check that the user is the admin, detaching to a 403 if they aren't.

=cut

sub assert_admin :Private {
	my ( $self, $c, $msg ) = @_;

	$msg //= 'You are not the admin.';
	$c->detach('/forbidden', [ $msg ]) unless $c->user->admin;
}

=head2 check_csrf_token

Check that the user provided their csrf token in the request parameters.

=cut

sub check_csrf_token :Private {
	my ( $self, $c, $msg ) = @_;

	$c->detach('/error', [ $msg // 'Bad session id.' ])
		if $c->req->param('csrf_token') ne $c->stash->{csrf_token};
}

=head2 strum

Mogrify certain words in the response body.

=cut

my %strum_list = (
	Sturm => 'Strum',
	PavFeira => 'PavFiera',
	PresentPerfect => 'PresentPrefect',
);

sub strum :Private {
	my ( $self, $c ) = @_;

	while( my($key, $strum) = each %strum_list )
	{
		while( (my $index = CORE::index $c->res->{body}, $key ) >= 0 )
		{
			substr( $c->res->{body}, $index, length $key ) = $strum;
		}
	}

}

=head2 render

Attempt to render a view, if needed.

=cut

sub render : ActionClass('RenderView') {}

sub end :Private {
	my ( $self, $c ) = @_;
	$c->forward('render');
	$c->forward('strum') if $c->config->{strum_ok} && rand > 0.5;
	$c->fillform( $c->stash->{fillform} ) if defined $c->stash->{fillform};
}

=head1 AUTHOR

Cameron Thornton E<lt>cthor@cpan.orgE<gt>

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
