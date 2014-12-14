#!/usr/bin/env perl
#
# This isn't a "real" makefile. Catalyst simply expects a file called
# "Makefile.PL" to exist as its herustic to find the root directory of the
# app, so I'm calling my installer script this.
#
# Don't try and install the app into your system. I don't think it's a good
# idea and can't guarantee things'll work if you do.

BEGIN {
	use 5.01;
	use FindBin '$Bin';
	chdir($Bin);
}

my @dependencies = (
	'Catalyst::Runtime~5.90013',
	'Catalyst::Restarter',
	'Catalyst::View::TT',
	'Template::Plugin::Cache',
	'Catalyst::View::JSON',
	'Catalyst::View::Email::Template',
	'Email::Sender::Transport::SMTP::TLS',
	'Catalyst::Plugin::ConfigLoader',
	'Catalyst::Plugin::Static::Simple',
	'Catalyst::Plugin::Unicode::Encoding',
	'Catalyst::Plugin::Authentication',
	'Catalyst::Authentication::Realm::SimpleDB',
	'Catalyst::Plugin::Authorization::Roles',
	'Catalyst::Plugin::Session',
	'Catalyst::Plugin::Session::Store::File',
	'Catalyst::Plugin::Session::State::Cookie',
	'Catalyst::Plugin::FormValidator::Simple',
	'Catalyst::Plugin::Cache',
	'Cache::Memory',
	'DateTime::Format::RFC3339',
	'FormValidator::Simple::Plugin::DBIC::Unique',
	'FormValidator::Simple::Plugin::Trim',
	'Catalyst::Plugin::Scheduler',
	'Catalyst::Plugin::FillInForm',
	'Catalyst::Plugin::Upload::MIME',
	'Catalyst::Plugin::RunAfterRequest',
	'Catalyst::TraitFor::Controller::reCAPTCHA',
	'Catalyst::Action::RenderView',
	'DBIx::Class',
	'DBIx::Class::TimeStamp',
	'DBIx::Class::PassphraseColumn',
	'DBIx::Class::InflateColumn::Serializer',
	'DBD::SQLite',
	'SQL::Script',
	'Moose',
	'MooseX::MarkAsMethods', # May be unnecessary with new non-moose Schema?
	'MooseX::NonMoose',      #
	'namespace::autoclean',
	'YAML::XS',
	'Config::General',
	'Catalyst::Plugin::Log::Handler',
	'Image::Magick',
	'Parse::BBCode',
	'Text::Markdown',
	'Try::Tiny',
	'IO::Prompt',
	'Digest::Whirlpool',
	'DateTime~1.01',
	'DateTime::Format::Human::Duration',
	'WWW::Fimfiction',
	'EBook::EPUB', # it has same req as View::Epub
);

if (eval { require App::cpanminus; 1; }) {
	*install = sub { system 'cpanm', @_ };
}
else {
	require CPAN;
	CPAN->import;
}

say "Installing dependencies...";
install(@dependencies);
