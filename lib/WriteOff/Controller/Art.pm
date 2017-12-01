package WriteOff::Controller::Art;
use Moose;
use namespace::autoclean;
use Digest::MD5;
use Imager;
use List::Util qw/min max/;
use Try::Tiny;

no warnings 'uninitialized';

BEGIN { extends 'Catalyst::Controller'; }

__PACKAGE__->config(model => 'Image');

sub _fetch :ActionClass('~Fetch') {}

sub fetch :Chained('/') :PathPart('art') :CaptureArgs(1) {
	my ($self, $c) = @_;
	$c->forward('_fetch');
	$c->stash->{entry} = $c->stash->{image}->entry;
	$c->stash->{event} = $c->stash->{entry}->event;
	unshift @{ $c->stash->{title} }, $c->stash->{event}->title;
}

sub view :Chained('fetch') :PathPart('') :Args(0) {
	my ( $self, $c ) = @_;

	if ($c->stash->{event}->art_gallery_opened) {
		my @gallery = $c->stash->{event}->images->gallery->all;
		my $i = 0;
		$i++ while $gallery[$i]->id != $c->stash->{entry}->id && $i < $#gallery;
		$c->stash->{num} = $gallery[$i]->num;
		$c->stash->{prev} = $gallery[$i-1];
		$c->stash->{next} = $gallery[$i-$#gallery];

		if ($c->stash->{event}->commenting) {
			$c->forward('/prepare_thread', [ $c->stash->{entry}->posts_rs ]);
		}

		if ($c->stash->{event}->fic_gallery_opened) {
			$c->stash->{storys} = $c->stash->{image}->storys->related_resultset('entry')->seed_order;
		}
	}

	$c->stash->{template} = 'art/view.tt';
}

sub gallery :Chained('/event/art') :PathPart('gallery') :Args(0) {
	my ( $self, $c ) = @_;

	$c->stash->{gallery} = $c->stash->{event}->images->gallery->search({}, { prefetch => 'image' });

	push @{ $c->stash->{title} }, 'Gallery';
	$c->stash->{template} = 'art/gallery.tt';
}

sub form :Private {
	my ($self, $c) = @_;

	if ($c->stash->{event}->fic2pic) {
		$c->stash->{rels} = $c->stash->{event}->storys->seed_order;
	}

	$c->stash->{mode} = 'art';
	$c->forward('/entry/form');
}

sub do_form :Private {
	my ( $self, $c ) = @_;

	$c->forward('/entry/do_form');

	my $upload = $c->req->upload('image');
	if ($upload) {
		$c->stash->{imager} = Imager->new(file => $upload->tempname)
			or die "Failed to read image: " . Imager->errstr . "\n";

		$c->req->params->{xpixels} = $c->stash->{imager}->getwidth;
		$c->req->params->{ypixels} = $c->stash->{imager}->getheight;
		$c->req->params->{filesize} = $upload->size;
	}

	$c->form(
		hovertext => [
			[ 'LENGTH', 1, $c->config->{len}{max}{alt} ],
			'TRIM_COLLAPSE',
		],
		xpixels   => [ [ 'GREATER_THAN', $c->config->{biz}{img}{xmin} - 1 ] ],
		ypixels   => [ [ 'GREATER_THAN', $c->config->{biz}{img}{ymin} - 1 ] ],
		filesize  => [ [ 'LESS_THAN', $c->config->{biz}{img}{size} ] ],
	);
}

sub do_write :Private {
	my ($self, $c) = @_;

	if (my $imgr = $c->stash->{imager}) {
		my $row = $c->stash->{image};
		my %biz = %{ $c->config->{biz}{img} };

		$row->version(substr Digest::MD5->md5_hex(rand), -6);

		try {
			# Resize if image too large
			if ($imgr->getwidth > $biz{xmax} || $imgr->getheight > $biz{ymax}) {
				$imgr = $imgr->scale(xpixels => $biz{xmax},
				                     ypixels => $biz{ymax},
				                     type => 'min') or die $imgr->errstr . "\n";
			}

			# Apply watermark if desired
			my $fontsize = min(900, $imgr->getwidth) / 18;

			my %ypos = (
				top => $fontsize,
				middle => $imgr->getheight / 2,
				bottom => $imgr->getheight - $fontsize,
			);

			if (my $y = $ypos{scalar $c->req->param('watermark')}) {
				my $layer = Imager->new(
					xsize => $imgr->getwidth,
					ysize => $imgr->getheight,
					channels => 4);
				my $border = $fontsize / 36;

				my $black = Imager::Color->new(0, 0, 0, 255);
				my $white = Imager::Color->new(255, 255, 255, 255);

				my %base = (
					string => $c->uri_for_action_abs('/art/view', [ $row->id ]),
					x => $imgr->getwidth / 2,
					y => $y,
					halign => 'center',
					valign => 'center',
					aa => 1,
					size => $fontsize,
					font => Imager::Font->new(
						file => $c->path_to('root/static/fonts/Z003-MediumItalic.otf')));

				for my $i (-1..1) {
					for my $j (-1..1) {
						my %p = %base;
						$p{x} = $base{x} + $i * $border;
						$p{y} = $base{y} + $j * $border;
						$layer->align_string(%p, color => $black) or die $layer->errstr . "\n";
					}
				}
				$layer->align_string(%base, color => $white) or die $layer->errstr . "\n";
				$imgr->compose(src => $layer, opacity => 0.25);
			}

			# Create a thumbnail for gallery
			my $thumb = $imgr->scale(xpixels => $biz{xmin}, ypixels => $biz{ymin}, type => 'min')
				or die $imgr->errstr . "\n";

			# Write and compress
			$row->mimetype('image/jpeg');
			my $fullpath = $c->path_to('root', $row->path);
			my $thumbpath = $c->path_to('root', $row->path('thumb'));

			my @base = (jpegquality => 90, jpeg_optimize => 1, i_background => 'white');
			$imgr->write(@base, file => $fullpath) or die $thumb->errstr . "\n";
			$thumb->write(@base, file => $thumbpath) or die $thumb->errstr . "\n";

			$row->filesize((stat $fullpath)[7]);
		} catch {
			$row->discard_changes if $row->in_storage;
			$c->stash->{error_msg} = $_;
		};

		$row->clean;
	}
}

sub submit :Chained('/event/art') :PathPart('submit') :Args(0) {
	my ( $self, $c ) = @_;

	$c->forward('form');

	if ($c->user) {
		$c->stash->{entrys} = $c->user->organises($c->stash->{event})
			? $c->stash->{event}->images
			: $c->stash->{event}->images->search({ user_id => $c->user->id });

		if ($c->req->method eq 'POST' && $c->stash->{event}->art_subs_allowed) {
			$c->forward('do_submit');
		}
	}

	push @{ $c->stash->{title} }, 'Submit';
	$c->stash->{template} = 'art/submit.tt';
}

sub do_submit :Private {
	my( $self, $c ) = @_;

	$c->forward('do_form');

	if (!$c->form->has_error && $c->req->upload('image')) {
		my $image = $c->stash->{image} = $c->model('DB::Image')->new_result({
			hovertext => $c->form->valid('hovertext'),
			filesize  => $c->form->valid('filesize'),
			mimetype  => 'image/jpeg',
			version   => 'temp',
		});

		# Choose a random ID until it works (i.e., until it's unique)
		my $maxid = 2 * ($c->model('DB::Image')->count + 1_000);
		while (!$image->in_storage) {
			$image->id(int rand $maxid);
			eval { $image->insert };
		}

		$c->forward('do_write');
		if (defined $c->stash->{error_msg}) {
			$image->delete and return;
		}
		else {
			$image->update;
		}

		$c->forward('/entry/do_submit');
		$c->stash->{entry}->image_id($image->id);
		$c->stash->{entry}->insert;
		$c->forward('/entry/do_rels');

		$c->log->info("Art %d submitted by %s: %s by %s (%.2fKB)",
			$image->id,
			$c->user->name,
			$c->form->valid('title'),
			$c->stash->{entry}->artist->name,
			$c->form->valid('filesize') / 1024,
		);
	}
}

sub edit :Chained('fetch') :PathPart('edit') :Args(0) {
	my ( $self, $c ) = @_;

	$c->detach('/forbidden', [ $c->string('cantEdit') ])
		if !$c->user->can_edit($c->stash->{image});

	$c->forward('form');
	$c->forward('do_edit') if $c->req->method eq 'POST';

	$c->stash->{fillform} = {
		artist     => $c->stash->{image}->entry->artist_id,
		title      => $c->stash->{image}->entry->title,
		story_id   => [ $c->stash->{image}->storys->get_column('id')->all ],
		hovertext  => $c->stash->{image}->hovertext,
	};

	push @{ $c->stash->{title} }, 'Edit';
	$c->stash->{template} = 'art/edit.tt';
}

sub do_edit :Private {
	my ( $self, $c ) = @_;

	$c->forward('do_form');

	if (!$c->form->has_error) {
		$c->forward('do_write');
		return if defined $c->stash->{error_msg};

		$c->stash->{image}->update({
			hovertext => $c->form->valid('hovertext'),
		});

		$c->forward('/entry/do_edit');
		$c->forward('/entry/do_rels');

		$c->log->info("Art %d edited by %s: %s by %s (%.2fKB)",
			$c->stash->{image}->id,
			$c->user->name,
			$c->form->valid('title'),
			$c->stash->{entry}->artist->name,
			$c->form->valid('filesize') / 1024,
		);
	}

}

sub delete :Chained('fetch') :PathPart('delete') :Args(0) {
	my ( $self, $c ) = @_;

	$c->forward('/entry/delete');
}

sub do_delete :Private {
	my ( $self, $c ) = @_;

	$c->forward('/check_csrf_token');
	$c->stash->{image}->version("")->clean;
	$c->forward('/entry/do_delete');
}

sub dq :Chained('fetch') :PathPart('dq') {
	my ($self, $c) = @_;

	$c->forward('/entry/dq');
}

sub rels :Chained('fetch') :PathPart('rels') :Args(0) {
	my ( $self, $c ) = @_;

	$c->detach('/default') if !$c->stash->{entry}->event->fic_gallery_opened;

	$c->stash->{items} = $c->stash->{image}->storys;
	$c->stash->{view} = $c->controller('Fic')->action_for('view');

	push @{ $c->stash->{title} }, 'Related Story(s)';
	$c->stash->{template} = 'item/list.tt';
}

sub results :Chained('/event/art') :PathPart('results') :Args(0) {
	my ($self, $c) = @_;

	$c->stash->{entrys} = $c->stash->{event}->images->eligible;
	$c->stash->{mode} = 'art';
	$c->stash->{view} = $self->action_for('view');
	$c->stash->{breakdown} = $self->action_for('votes');

	$c->forward('/event/results');
}

sub votes :Chained('fetch') :PathPart('votes') :Args(1) {
	my ($self, $c, $round) = @_;

	$c->forward('/entry/votes', [ $round ]);
}

=head1 AUTHOR

Cameron Thornton E<lt>cthor@cpan.orgE<gt>

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
