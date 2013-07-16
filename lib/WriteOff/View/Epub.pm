package WriteOff::View::Epub;
use utf8;
use Moose;

use EBook::EPUB::Metadata;
use EBook::EPUB::Manifest;
use EBook::EPUB::Guide;
use EBook::EPUB::Spine;
use EBook::EPUB::NCX;

use EBook::EPUB::Container::Zip;

use Data::UUID;
use File::Temp qw/tempdir/;
use File::Basename qw/dirname fileparse/;
use File::Copy;
use File::Path;
use Carp;

extends 'Catalyst::View';

__PACKAGE__->mk_accessors( qw( static_folder stylesheet cover author anonymous language skip_cover prefix templates ) );

has metadata => (
	isa     => 'Object', 
	is      => 'ro',
	default => sub { EBook::EPUB::Metadata->new() },
	handles => [ qw/add_contributor
					add_creator
					add_coverage
					add_date
					add_meta_dcitem
					add_description
					add_format
					add_meta_item
					add_language
					add_publisher
					add_relation
					add_rights
					add_source
					add_subject
					add_translator
					add_type
				/],
	clearer => '_clear_metadata',
	lazy    => 1,
);

has manifest => (
	isa     => 'Object', 
	is      => 'ro',
	default => sub { EBook::EPUB::Manifest->new() },
	clearer => '_clear_manifest',
	lazy    => 1,
);

has spine => (
	isa     => 'Object', 
	is      => 'ro',
	default => sub { EBook::EPUB::Spine->new() },
	clearer => '_clear_spine',
	lazy    => 1,
);

has guide => (
	isa     => 'Object', 
	is      => 'ro',
	default => sub { EBook::EPUB::Guide->new() },
	clearer => '_clear_guide',
	lazy    => 1,
);

has ncx => (
	isa     => 'Object', 
	is      => 'ro',
	default => sub { EBook::EPUB::NCX->new() },
	handles => [ qw/add_navpoint/ ],
	clearer => '_clear_ncx',
	lazy    => 1,
);

has _uuid => (
	isa     => 'Str',
	is      => 'rw',
	clearer => '_clear_uuid',
	default => '',
	lazy    => 1,
);

has id_counters => ( 
	isa     => 'HashRef', 
	is      => 'ro', 
	default =>  sub { {} },
	clearer => '_clear_id_counters',
	lazy    => 1,
);
has tmpdir => ( 
	isa     => 'Str', 
	is      => 'rw', 
	default =>  sub { tempdir( CLEANUP => 1 ); },
	clearer => '_clear_tmpdir',
	lazy    => 1,
);

sub clear {
	my ( $self ) = shift;

	$self->_clear_metadata;
	$self->_clear_manifest;
	$self->_clear_spine;
	$self->_clear_guide;
	$self->_clear_ncx;
	$self->_clear_uuid;
	$self->_clear_id_counters;
	$self->_clear_tmpdir;
};

sub process {
	my ( $self, $c ) = @_;

	# Prepare
	$self->manifest->add_item(
		id			=> 'ncx',
		href		=> 'toc.ncx', 
		media_type	=> 'application/x-dtbncx+xml'
	);

	$self->spine->toc('ncx');
	mkdir ($self->tmpdir . "/OPS") or die "Can't make OPS dir in " . $self->tmpdir;
	# Implicitly generate UUID for book
	my $ug = new Data::UUID;
	my $uuid = $ug->create_str();
	$self->_set_uuid( $uuid );
	
	#start adding general
	$self->copy_stylesheet( $self->static_folder . '/' . $self->stylesheet, $self->stylesheet );
	$self->add_language( $self->language );
	
	#cover
	unless ( $self->skip_cover ) {
		my $cover_img = $self->copy_image( $self->static_folder . '/' . $self->cover, $self->cover );
		my $cover_xhtml = $c->view( "XHTML" )->render( $c, $self->templates->{cover} );
		my $cover_id = $self->add_xhtml( 'cover.xhtml', $cover_xhtml, linear => 'no' );
		$self->add_meta_item( 'cover', $cover_img );
		# meta cover isn't accepted by all ereaders, so add cover as page
		$self->add_reference({
				type   => 'cover',
				href   => 'cover.xhtml',
				title  => 'Cover',
		});
	}

	# single story ebook
	if ( exists $c->stash->{story} ) {
		$self->add_title( $c->stash->{story}->title );
		my $author = $c->stash->{story}->author;
		$author = $self->anonymous unless $c->stash->{event}->is_ended;
		$self->add_author( $author );
		my $story_xml = $c->view( "XHTML" )->render( $c, $self->templates->{chapter} );
		my $story_id = $self->add_xhtml( $self->prefix->{chapter} . '.xhtml', $story_xml, linear => 'yes' );
		$self->add_navpoint(
			label      => $c->stash->{story}->title,
			id         => $story_id,
			content    => $self->prefix->{chapter} . '.xhtml',
			play_order => 1,
		);
		if ( $c->stash->{event}->art ) {
			for my $image( $c->stash->{story}->images->all ) {
				$self->add_image( $image->filename( $self->prefix->{image} ), $image->contents, $image->mimetype );
			}
		}
	}
	# multi story ebook
	elsif ( exists $c->stash->{event} ) {
		my $i = 1;
		$self->add_title( $c->stash->{event}->prompt );
		$self->add_author( $self->author );
		if ( $c->stash->{event}->art ) {
			for my $image( $c->stash->{event}->images->all ) {
				$self->add_image( $image->filename( 'images/image' ), $image->contents, $image->mimetype );
			}
		}
		for my $story( $c->stash->{event}->storys->all ) {
			$c->stash->{story} = $story;
			my $story_xhtml = $c->view( "XHTML" )->render( $c, $self->templates->{chapter} );
			my $story_id = $self->add_xhtml( $self->prefix->{chapter} . $i . '.xhtml', $story_xhtml, linear => 'yes' );
			my $title = $story->title;
			$title .= ' by ' . $story->author if $c->stash->{event}->is_ended;
			$self->add_navpoint(
				label      => $title,
				id         => $story_id,
				content    => $self->prefix->{chapter} . $i . '.xhtml',
				play_order => $i,
			);
			$i = $i + 1;
		}
	}

	my $zip = File::Temp->new( SUFFIX => '.epub' );
	$self->pack_zip( $zip->filename );
	my $output = do { local $/; <$zip> };
	$c->response->body( $output );

	#clean up
	$self->clear;
	File::Temp::cleanup();
}

sub to_xml {
	my ( $self ) = @_;
	my $xml;

	my $writer = XML::Writer->new(
		OUTPUT      => \$xml,
		DATA_MODE   => 1,
		DATA_INDENT => 2,
	);

	$writer->xmlDecl( "utf-8" );
	$writer->startTag( 'package', 
		xmlns               => 'http://www.idpf.org/2007/opf',
		version             => '2.0',
		'unique-identifier' => 'BookId',
	);
	$self->metadata->encode( $writer );
	$self->manifest->encode( $writer );
	$self->spine->encode( $writer );
	$self->guide->encode( $writer );
	$writer->endTag( 'package' );
	$writer->end;

	return $xml;
}

sub add_author {
	my ( $self, $author, $formal ) = @_;
	$self->metadata->add_author( $author, $formal );
	$self->ncx->add_author( $author );
}

sub add_title {
	my ( $self, $title ) = @_;
	$self->metadata->add_title( $title );
	my $ncx_title =  $self->ncx->title;
	# Collect all titles in a row for NCX
	$title = "$ncx_title $title" if ( defined( $ncx_title ) );
	$self->ncx->title( $title );
}

sub _set_uuid {
	my ( $self, $uuid ) = @_; 

	# Just some naive check for key to be UUID
	if ( $uuid !~ /^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$/i ) {
		carp "$uuid - is not valid UUID";
		return;
	}
	my $key = $uuid;

	$key =~ s/-//g;
	$key =~ s/([a-f0-9]{2})/chr(hex($1))/egi;
	if ( defined( $self->_uuid ) ) {
		warn "Overriding existing uuid " . $self->_uuid;
		$self->_uuid( $uuid );
	}

	$self->ncx->uid( "urn:uuid:$uuid" );
	$self->metadata->set_book_id( "urn:uuid:$uuid" );
	$self->_uuid( $uuid );
}

sub add_identifier {
	my ( $self, $ident, $scheme ) = @_;
	if ( $ident =~ /^urn:uuid:(.*)/i ) {
		my $uuid = $1;
		$self->_set_uuid( $uuid );
	}
	else {
		$self->metadata->add_identifier( $ident, $scheme );
	}
}

sub add_xhtml_entry {
	my ( $self, $filename, %opts ) = @_;
	my $linear = 1;

	$linear = 0 if ( defined ( $opts{linear} ) && 
			$opts{linear} eq 'no');


	my $id = $self->nextid( 'ch' );
	$self->manifest->add_item(
		id          => $id,
		href        => $filename,
		media_type  => 'application/xhtml+xml',
	);

	$self->spine->add_itemref(
		idref       => $id,
		linear      => $linear,
	);

	return $id;
}

sub add_stylesheet_entry {
	my ( $self, $filename ) = @_;
	my $id = $self->nextid( 'css' );
	$self->manifest->add_item(
		id          => $id,
		href        => $filename,
		media_type  => 'text/css',
	);

	return $id;
}

sub add_image_entry {
	my ( $self, $filename, $type ) = @_;
	# trying to guess
	if ( !defined( $type ) ) {
		if ( ( $filename =~ /\.jpg$/i ) || ( $filename =~ /\.jpeg$/i ) ) {
			$type = 'image/jpeg';
		}
		elsif ( $filename =~ /\.gif$/i ) {
			$type = 'image/gif';
		}
		elsif ( $filename =~ /\.png$/i ) {
			$type = 'image/png';
		}
		elsif ( $filename =~ /\.svg$/i ) {
			$type = 'image/svg+xml';
		}
		else {
			croak ( "Unknown image type for file $filename" );
			return;
		}
	}

	my $id = $self->nextid( 'img' );
	$self->manifest->add_item(
		id          => $id,
		href        => $filename,
		media_type  => $type,
	);

	return $id;
}

sub add_entry {
	my ( $self, $filename, $type ) = @_;
	my $id = $self->nextid( 'item' );
	$self->manifest->add_item(
		id          => $id,
		href        => $filename,
		media_type  => $type,
	);

	return $id;
}
sub add_xhtml {
	my ( $self, $filename, $data, %opts ) = @_;
	my $tmpdir = $self->tmpdir;
	my ( $name, $dir ) = fileparse( $filename );
	_mkdir( "$tmpdir/OPS/$dir" );
	open F, ">:utf8", "$tmpdir/OPS/$filename";
	print F $data;
	close F;

	return $self->add_xhtml_entry( $filename, %opts );
}

sub add_stylesheet {
	my ( $self, $filename, $data ) = @_;
	my $tmpdir = $self->tmpdir;
	my ( $name, $dir ) = fileparse( $filename );
	_mkdir( "$tmpdir/OPS/$dir" );
	open F, ">:utf8", "$tmpdir/OPS/$filename";
	print F $data;
	close F;

	return $self->add_stylesheet_entry( $filename );
}

sub add_image {
	my ( $self, $filename, $data, $type ) = @_;
	my $tmpdir = $self->tmpdir;
	my ( $name, $dir ) = fileparse( $filename );
	_mkdir( "$tmpdir/OPS/$dir" );
	open F, "> $tmpdir/OPS/$filename";
	binmode F;
	print F $data;
	close F;

	return $self->add_image_entry( $filename, $type );
}

sub add_data {
	my ( $self, $filename, $data, $type ) = @_;
	my $tmpdir = $self->tmpdir;
	my ( $name, $dir ) = fileparse( $filename );
	_mkdir( "$tmpdir/OPS/$dir" );
	open F, "> $tmpdir/OPS/$filename";
	binmode F;
	print F $data;
	close F;

	return $self->add_entry( $filename, $type );
}


sub copy_xhtml {
	my ( $self, $src_filename, $filename, %opts ) = @_;
	my $tmpdir = $self->tmpdir;
	my ( $name, $dir ) = fileparse( $filename );
	_mkdir( "$tmpdir/OPS/$dir" );
	if ( mkdir_and_copy( $src_filename, "$tmpdir/OPS/$filename" ) ) {
		return $self->add_xhtml_entry( $filename, %opts );
	}
	else {
		carp ( "Failed to copy $src_filename to $tmpdir/OPS/$filename" );
	}

	return;
}

sub copy_stylesheet {
	my ( $self, $src_filename, $filename ) = @_;
	my $tmpdir = $self->tmpdir;
	my ( $name, $dir ) = fileparse( $filename );
	_mkdir( "$tmpdir/OPS/$dir" );
	if ( mkdir_and_copy( $src_filename, "$tmpdir/OPS/$filename" ) ) {
		return $self->add_stylesheet_entry( "$filename" );
	}
	else {
		carp ( "Failed to copy $src_filename to $tmpdir/OPS/$filename" );
	}

	return;
}

sub copy_image {
	my ( $self, $src_filename, $filename, $type ) = @_;
	my $tmpdir = $self->tmpdir;
	my ( $name, $dir ) = fileparse( $filename );
	_mkdir( "$tmpdir/OPS/$dir" );
	if ( mkdir_and_copy( $src_filename, "$tmpdir/OPS/$filename" ) ) {
		return $self->add_image_entry( "$filename" );
	}
	else {
		carp ( "Failed to copy $src_filename to $tmpdir/OPS/$filename" );
	}

	return;
}

sub copy_file {
	my ( $self, $src_filename, $filename, $type ) = @_;
	my $tmpdir = $self->tmpdir;
	my ( $name, $dir ) = fileparse( $filename );
	_mkdir( "$tmpdir/OPS/$dir" );
	if ( mkdir_and_copy( $src_filename, "$tmpdir/OPS/$filename" ) ) {
		my $id = $self->nextid( 'id' );
		$self->manifest->add_item(
			id          => $id,
			href        => "$filename",
			media_type  => $type,
		);
		return $id;
	}
	else {
		carp ( "Failed to copy $src_filename to $tmpdir/OPS/$filename" );
	}

	return;
}

sub nextid {
	my ( $self, $prefix ) = @_;
	my $id;

	$prefix = 'id' unless( defined( $prefix ) );
	if ( defined( ${$self->id_counters}{$prefix} ) ) {
		$id = "$prefix" . ${$self->id_counters}{$prefix};
		${$self->id_counters}{$prefix}++;
	}
	else
	{
		# First usage of prefix
		$id = "${prefix}1";
		${$self->id_counters}{$prefix} = 2;
	}

	return $id;
}

sub pack_zip {
	my ( $self, $filename ) = @_;
	my $tmpdir = $self->tmpdir;
	$self->write_ncx( "$tmpdir/OPS/toc.ncx" );
	$self->write_opf( "$tmpdir/OPS/content.opf" );
	my $container = EBook::EPUB::Container::Zip->new( $filename );
	$container->add_path( $tmpdir . "/OPS", "OPS/" );
	$container->add_root_file( "OPS/content.opf", "application/oebps-package+xml" );
	return $container->write;
}

sub write_opf {
	my ( $self, $filename ) = @_;
	open F, ">:utf8", $filename or die "Failed to create OPF file: $filename";
	my $xml = $self->to_xml;
	print F $xml;
	close F;
}

sub write_ncx {
	my ( $self, $filename ) = @_;
	open F, ">:utf8", $filename or die "Failed to create NCX file: $filename";
	my $xml = $self->ncx->to_xml;
	print F $xml;
	close F;
}


sub add_reference {
	my ( $self, @args ) = @_;
	$self->guide->add_reference( @args );
}

sub _mkdir {
	my ( $dir ) = @_;
	mkpath( $dir );
}

sub mkdir_and_copy {
	my ( $from, $to ) = @_;
	mkpath( dirname( $to ) );
	return copy( $from, $to );
}

1;
