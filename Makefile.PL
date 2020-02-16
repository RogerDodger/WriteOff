#!/usr/bin/env perl
#
# This isn't a "real" makefile. Catalyst simply expects a file called
# "Makefile.PL" to exist as its herustic to find the root directory of the
# app, so I'm calling my installer script this.
#
# Don't try and install the app into your system. I don't think it's a good
# idea and can't guarantee things'll work if you do.

use 5.01;

my @dependencies = (
   'Catalyst::Runtime',
   'Catalyst::Restarter',
   'Catalyst::View::TT',
   'Catalyst::View::JSON',
   'Email::Sender::Simple',
   'Email::MIME',
   'CSS::Inliner',
   'Template::Plugin::Cache',
   'Template::AutoFilter::Parser',
   'Catalyst::Plugin::ConfigLoader',
   'Catalyst::Plugin::Static::Simple',
   'Catalyst::Plugin::Unicode::Encoding',
   'Crypt::URandom',
   'Math::Random::ISAAC::XS',
   'Session::Storage::Secure',
   'Catalyst::Plugin::FormValidator::Simple',
   'Catalyst::Plugin::Cache',
   'Cache::FastMmap',
   'Cache::Memory',
   'CHI',
   'FormValidator::Simple::Plugin::DBIC::Unique',
   'FormValidator::Simple::Plugin::Trim',
   'Catalyst::Plugin::FillInForm',
   'Catalyst::Plugin::Upload::MIME',
   'Catalyst::Plugin::RunAfterRequest',
   'Catalyst::Action::RenderView',
   'Catalyst::Model::DBIC::Schema',
   'DBIx::Class',
   'DBIx::Class::FilterColumn',
   'DBIx::Class::InflateColumn::Serializer',
   'DBIx::Class::TimeStamp',
   'DBD::SQLite',
   'SQL::Script',
   'YAML::XS',
   'Parse::BBCode',
   'Text::Markdown',
   'Try::Tiny',
   'IO::Prompt',
   'Bytes::Random::Secure',
   'Crypt::Eksblowfish::Bcrypt',
   'Digest::Whirlpool',
   'Digest::SHA1',
   'Digest::MD5',
   'DateTime',
   'DateTime::Format::Human::Duration',
   'DateTime::Format::RFC3339',
   'EBook::EPUB',
   'Class::Null',
   'Imager',
   'Imager::File::PNG',
   'Imager::File::JPEG',
   'ImageR::File::WEBP',
   'Graphics::ColorNames::Netscape', # Dependencies of Graphics::ColorObject,
   'Graphics::ColorNames::Windows',  # but it doesn't include them in its own
   'Graphics::ColorNames::HTML',     # Makefile.PL
   'Graphics::ColorObject',
   'JSON',
   'Captcha::noCAPTCHA',
   'LWP::Protocol::https',
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
