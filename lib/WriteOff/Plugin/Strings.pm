package WriteOff::Plugin::Strings;

use 5.014;
use Carp;
use File::Find ();
use Text::Markdown;

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

			my $html = Text::Markdown->new->markdown($text);

			$html =~ s{ <h1> (.+?) </h1> }{}x;
			$doc->{title} = $1;
			$doc->{sections} = [];
			while ($html =~ m{ <h2>(.*?)</h2> (.*?) (?=<h2>|$) }xsg) {
				my $contents = $2;
				push $doc->{sections}, { title => $1, topics => [] };
				while ($contents =~ m{ <h3>(.*?)</h3> (.*?) (?=<h3>|$) }xsg) {
					push $doc->{sections}->[-1]->{topics}, { title => $1, contents => $2 };
				}
			}
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
	dd %docs;
	_fetch(@_, \%docs);
}

sub string {
	_fetch(@_, \%strings);
}

1;
