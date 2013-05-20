#!/usr/bin/env perl
# IMPORTANT: if you delete this file your app will not work as
# expected.  You have been warned.
use inc::Module::Install 1.02;
use Module::Install::Catalyst; # Complain loudly if you don't have
                               # Catalyst::Devel installed or haven't said
                               # 'make dist' to create a standalone tarball.

name 'WriteOff';
all_from 'lib/WriteOff.pm';

requires (
	'Catalyst::Runtime' => '5.90013',
	'Catalyst::View::TT' => 0,
	'Catalyst::View::JSON' => 0,
	'Catalyst::View::Email::Template' => 0,
	'Catalyst::Plugin::ConfigLoader' => 0,
	'Catalyst::Plugin::Static::Simple' => 0,
	'Catalyst::Plugin::Unicode::Encoding' => 0,
	'Catalyst::Plugin::Authentication' => 0,
	'Catalyst::Authentication::Realm::SimpleDB' => 0,
	'Catalyst::Plugin::Authorization::Roles' => 0,
	'Catalyst::Plugin::Session' => 0,
	'Catalyst::Plugin::Session::Store::File' => 0,
	'Catalyst::Plugin::Session::State::Cookie' => 0,
	'Catalyst::Plugin::FormValidator::Simple' => 0,
	'DateTime::Format::RFC3339' => 0,
	'FormValidator::Simple::Plugin::DBIC::Unique' => 0,
	'FormValidator::Simple::Plugin::Trim' => 0,
	'Catalyst::Plugin::Scheduler' => 0,
	'Catalyst::Plugin::FillInForm' => 0,
	'Catalyst::Plugin::Upload::MIME' => 0,
	'Catalyst::Plugin::RunAfterRequest' => 0,
	'Catalyst::TraitFor::Controller::reCAPTCHA' => 0,
	'Catalyst::Action::RenderView' => 0,
	'DBIx::Class' => 0,
	'DBIx::Class::TimeStamp' => 0,
	'DBIx::Class::PassphraseColumn' => 0,
	'DBIx::Class::InflateColumn::Serializer' => 0,
	'Moose' => 0,
	'namespace::autoclean' => 0,
	'Config::General' => 0,
	'Catalyst::Plugin::Log::Handler' => 0,
	'Image::Magick' => 0,
	'Parse::BBCode' => 0,
	'Text::Markdown' => 0,
	'WWW::Fimfiction' => 0,
	'Try::Tiny' => 0,
	'IO::Prompt' => 0,
	'Digest::Whirlpool' => 0,
	'DateTime::Format::Human::Duration' => 0,
	'DateTime' => '1.01'
);

test_requires 'Test::More' => '0.88';
catalyst;

install_script glob('script/*.pl');
auto_install;
WriteAll;
