package EBook::Creator;
use utf8;
use Moose;

extends 'EBook::EPUB';
use File::Path;
use File::Basename;
use File::Copy;
use Carp;

sub add_xhtml {
	my ($self, $filename, $data, %opts) = @_;
	my $tmpdir = $self->tmpdir;
	my ($name, $dir) = fileparse($filename);
	_mkdir("$tmpdir/OPS/$dir");
	open F, ">:utf8", "$tmpdir/OPS/$filename";
	print F $data;
	close F;

	return $self->add_xhtml_entry($filename, %opts);
}

sub add_stylesheet {
	my ($self, $filename, $data) = @_;
	my $tmpdir = $self->tmpdir;
	my ($name, $dir) = fileparse($filename);
	_mkdir("$tmpdir/OPS/$dir");
	open F, ">:utf8", "$tmpdir/OPS/$filename";
	print F $data;
	close F;

	return $self->add_stylesheet_entry($filename);
}

sub add_image {
	my ($self, $filename, $data, $type) = @_;
	my $tmpdir = $self->tmpdir;
	my ($name, $dir) = fileparse($filename);
	_mkdir("$tmpdir/OPS/$dir");
	open F, "> $tmpdir/OPS/$filename";
	binmode F;
	print F $data;
	close F;

	return $self->add_image_entry($filename, $type);
}

sub add_data {
	my ($self, $filename, $data, $type) = @_;
	my $tmpdir = $self->tmpdir;
	my ($name, $dir) = fileparse($filename);
	_mkdir("$tmpdir/OPS/$dir");
	open F, "> $tmpdir/OPS/$filename";
	binmode F;
	print F $data;
	close F;

	return $self->add_entry($filename, $type);
}


sub copy_xhtml
{
	my ($self, $src_filename, $filename, %opts) = @_;
	my $tmpdir = $self->tmpdir;
	my ($name, $dir) = fileparse($filename);
	_mkdir("$tmpdir/OPS/$dir");
	if (mkdir_and_copy($src_filename, "$tmpdir/OPS/$filename")) {
		return $self->add_xhtml_entry($filename, %opts);
	}
	else {
		carp ("Failed to copy $src_filename to $tmpdir/OPS/$filename");
	}

	return;
}

sub copy_stylesheet
{
	my ($self, $src_filename, $filename) = @_;
	my $tmpdir = $self->tmpdir;
	my ($name, $dir) = fileparse($filename);
	_mkdir("$tmpdir/OPS/$dir");
	if (mkdir_and_copy($src_filename, "$tmpdir/OPS/$filename")) {
		return $self->add_stylesheet_entry("$filename");
	}
	else {
		carp ("Failed to copy $src_filename to $tmpdir/OPS/$filename");
	}

	return;
}

sub copy_image
{
	my ($self, $src_filename, $filename, $type) = @_;
	my $tmpdir = $self->tmpdir;
	my ($name, $dir) = fileparse($filename);
	_mkdir("$tmpdir/OPS/$dir");
	if (mkdir_and_copy($src_filename, "$tmpdir/OPS/$filename")) {
		return $self->add_image_entry("$filename");
	}
	else {
		carp ("Failed to copy $src_filename to $tmpdir/OPS/$filename");
	}

	return;
}

sub copy_file
{
	my ($self, $src_filename, $filename, $type) = @_;
	my $tmpdir = $self->tmpdir;
	my ($name, $dir) = fileparse($filename);
	_mkdir("$tmpdir/OPS/$dir");
	if (mkdir_and_copy($src_filename, "$tmpdir/OPS/$filename")) {
		my $id = $self->nextid('id');
		$self->manifest->add_item(
			id			=> $id,
			href		=> "$filename",
			media_type	=> $type,
		);
		return $id;
	}
	else {
		carp ("Failed to copy $src_filename to $tmpdir/OPS/$filename");
	}

	return;
}

sub add_reference {
	my ( $self, @args ) = @_;
	$self->guide->add_reference(@args);
}

sub _mkdir {
	my ( $dir ) = @_;
	mkpath($dir);
}
sub mkdir_and_copy {
	my ($from, $to) = @_;
	mkpath(dirname($to));
	return copy($from, $to);
}

no Moose;
__PACKAGE__->meta->make_immutable;

1;

