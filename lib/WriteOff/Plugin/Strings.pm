package WriteOff::Plugin::Strings;

use Carp;
use File::Find ();

my %files;

sub setup {
	my $app = shift;

	File::Find::find sub {
		my $file = $files{$_} = {};

		open my $fh, $_;
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
				$file->{$key} = $value;
			}
		}
		close $fh;
	}, $app->path_to('data', 'strings');

	$app->next::method(@_);
}

sub strings {
	my ($app, $key) = @_;

	my $lang = $app->user->lang;
	my $strings = exists $files{$lang} ? $files{$lang} : $files{en};

	if (defined $string) {
		return $strings->{$key};
	}
	else {
		return $strings;
	}
}

1;
