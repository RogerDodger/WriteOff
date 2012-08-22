#!/usr/bin/env perl
# IMPORTANT: if you delete this file your app will not work as
# expected.  You have been warned.
use inc::Module::Install 1.02;
use Module::Install::Catalyst; # Complain loudly if you don't have
                               # Catalyst::Devel installed or haven't said
                               # 'make dist' to create a standalone tarball.

name 'WriteOff';

requires 'Catalyst::Runtime' => '5.90013';
requires 'Catalyst::Plugin::ConfigLoader';
requires 'Catalyst::Plugin::Static::Simple';
requires 'Catalyst::Plugin::Unicode::Encoding';
requires 'Catalyst::Plugin::Authentication';
requires 'Catalyst::Plugin::Authorization::Roles';
requires 'Catalyst::Plugin::Session';
requires 'Catalyst::Plugin::Session::Store::File';
requires 'Catalyst::Plugin::Session::Store::Cookie';
requires 'Catalyst::Plugin::FormValidator::Simple';
requires 'FormValidator::Simple::Plugin::DBIC::Unique';
requires 'Catalyst::Plugin::FillInForm';
requires 'Catalyst::Plugin::Upload::MIME';
requires 'Catalyst::TraitFor::Controller::reCAPTCHA';
requires 'Catalyst::Action::RenderView';
requires 'DBIx::Class::TimeStamp';
requires 'DBIx::Class::PassphraseColumn';
requires 'Moose';
requires 'namespace::autoclean';
requires 'Config::General';
requires 'Image::Magick';
requires 'Parse::BBCode';
test_requires 'Test::More' => '0.88';
catalyst;

install_script glob('script/*.pl');
auto_install;
WriteAll;
