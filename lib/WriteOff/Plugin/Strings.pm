package WriteOff::Plugin::Strings;

use 5.014;
use Carp;
use File::Find ();
use HTML::Entities;
use Text::Markdown;
use WriteOff::Util;

my %docs;
my %strings;

sub setup {
	my $app = shift;

	File::Find::find sub {
		if ($File::Find::name =~ m{/(\w+)/strings$}) {
			my $map = $strings{$1} = {};

			open my $fh, '<:utf8', $_;
			my $lineNo = 0;
			while (my $line = readline $fh) {
				$lineNo++;
				chomp $line;
				next if $line =~ /^;/ || !length $line;

				my ($key, $value) = split /=/, $line, 2;

				if ($key =~ /\s/ || !defined $value) {
					$app->log->warn("Format error in strings/$_ on line $lineNo");
				}
				else {
					$map->{$key} = $value;
				}
			}
			close $fh;
		}
		elsif ($File::Find::name =~ m{/(\w+)/(\w+)\.md$}) {
			$docs{$1} //= {};
			my $doc = $docs{$1}{$2} = {};

			open my $fh, '<:utf8', $_;
			my $text = do { local $/ = <$fh> };
			close $fh;

			$doc->{contents} = Text::Markdown->new->markdown($text);
			$doc->{contents} =~ s{ <h1> (.+?) </h1> }{}x;
			$doc->{title} = HTML::Entities::decode_entities $1;
			$doc->{sections} = [];
			1 while $doc->{contents} =~ s{
				<(h[23])> (.*?) </\g1>
			}{
				my $class = { h2 => 'section', h3 => 'topic' }->{$1};
				my $title = $2;
				my $id = WriteOff::Util::simple_uri $title;
				push $doc->{sections}, { class => $class, id => $id, title => $title };
				qq{
					<div id="$id" class="Document-$class--title">$title</div>
				}
			}xsge;
		}
	}, $app->path_to('lang');

	$app->next::method(@_);
}

use Data::Dump;

sub _fetch {
	my ($app, $key, $maps) = @_;
	($maps->{$app->lang} // $maps->{en})->{$key} // $maps->{en}{$key};
}

sub document {
	_fetch(@_, \%docs);
}

sub string {
	_fetch(@_, \%strings);
}

1;
