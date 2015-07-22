package WriteOff::Plugin::Preprocessor;

require Text::Sass::XS;

sub setup {
	my $app = shift;

	SCSS: {
		my $in  = $app->path_to(qw/root static style scss writeoff.scss/);
		my $out = $app->path_to(qw/root static style writeoff.css/);
		my $dir = $app->path_to(qw/root static style scss/);

		my ($css, $err) = Text::Sass::XS::sass_compile_file($in, { output_style => 2 });

		if ($err) {
			$app->log->error($err);
		} else {
			if (-e $out) {
				$app->log->debug("Overwrite $out");
			} else {
				$app->log->debug("Write $out");
			}
			open my $fh, '>:utf8', $out;
			print $fh $css;
			close $fh;
		}
	}

	$app->next::method(@_);
}

"Who will watch the watchmen?";
