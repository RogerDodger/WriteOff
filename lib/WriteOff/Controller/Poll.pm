package WriteOff::Controller::Poll;
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller'; }

=head1 NAME

WriteOff::Controller::Poll - Catalyst Controller

=head1 DESCRIPTION

Use the writeoff ranking system on arbitrary lists of items

=cut

sub fetch :ActionClass('~Fetch') {}

sub submit :Path('/polls') :Args(0) {
   my ($self, $c) = @_;

   $c->forward('do_submit') if $c->user && $c->req->method eq 'POST';

   $c->stash->{template} = 'poll/submit.tt';
   push @{ $c->stash->{title} }, $c->string('polls');
}

sub do_submit :Private {
   my ($self, $c) = @_;

   $c->forward('/check_csrf_token');

   my $title = substr $c->paramo('title'), 0, $c->config->{len}{max}{title};
   my @bids;
   for my $bid ($c->req->param('bid')) {
      if ($bid =~ /\w+/) {
         push @bids, substr $bid =~ s/^\s+|\s+$//gr, 0, $c->config->{len}{max}{title};
         $c->log->debug($bids[-1]);
      }
   }

   if (@bids > 2) {
      $c->log->debug("Creating new poll: $title");
      my $poll = $c->user->create_related(polls => { title => $title });
      $poll->create_related(bids => { name => $_ }) for @bids;
   }
}

=head1 AUTHOR

Cameron Thornton E<lt>cthor@cpan.orgE<gt>

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
