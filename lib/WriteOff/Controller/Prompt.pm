package WriteOff::Controller::Prompt;
use Moose;
use WriteOff::Util qw/uniq/;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller'; }

=head1 NAME

WriteOff::Controller::Prompt - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=head2 index

=cut

sub fetch :Chained('/') :PathPart('prompt') :CaptureArgs(1) :ActionClass('~Fetch') {}

sub vote :Chained('/event/prompt') :PathPart('vote') :Args(0) {
   my ( $self, $c ) = @_;

   $c->stash->{prompts} = $c->stash->{event}->prompts->ballot($c->user->offset);

   if ($c->user) {
      $c->stash->{votes} = {
         map { $_->prompt_id => $_->value }
            $c->user->prompt_votes->search(
               { event_id => $c->stash->{event}->id },
               { join => 'prompt' }
            )
      };
   }

   $c->stash->{show_results} = $c->stash->{event}->has_started;

   if ($c->stash->{event}->prompt_votes_allowed) {
      $c->forward('do_vote') if $c->req->method eq 'POST';
   }

   $c->stash->{template} = 'prompt/vote.tt';
}

sub _do_vote :ActionClass("~Vote");

sub do_vote :Private {
   my ( $self, $c ) = @_;
   $c->stash->{prompt} = $c->stash->{prompts}->find_maybe($c->req->param('prompt'));
   $c->forward('_do_vote');
   $c->res->redirect($c->req->uri) if !defined $c->res->body;
}

sub submit :Chained('/event/prompt') :PathPart('submit') :Args(0) {
   my ( $self, $c ) = @_;

   $c->stash->{prompts} = $c->stash->{event}->prompts->search({ user_id => $c->user_id });

   my $subs_left = sub {
      return 0 unless $c->user;
      return $c->config->{prompts_per_user} - $c->stash->{prompts}->count;
   };

   $c->req->params->{subs_left} = $subs_left->();

   $c->forward('do_submit')
      if $c->req->method eq 'POST'
      && $c->user
      && $c->stash->{event}->prompt_subs_allowed;

   $c->stash->{subs_left} = $subs_left->();

   push @{ $c->stash->{title} }, 'Submit';
   $c->stash->{template} = 'prompt/submit.tt';
}

sub do_submit :Private {
   my ( $self, $c ) = @_;

   $c->forward('/check_csrf_token');

   $c->form(
      prompt => [
         'NOT_BLANK',
         [ 'LENGTH', 1, $c->config->{len}{max}{prompt} ],
         'TRIM_COLLAPSE',
         [ 'DBIC_UNIQUE', $c->stash->{event}->prompts_rs, 'contents' ],
      ],
      subs_left => [ [ 'GREATER_THAN', 0 ] ],
   );

   if (!$c->form->has_error) {
      my $prompt = $c->stash->{event}->create_related('prompts', {
         user_id  => $c->user->id,
         contents => $c->form->valid('prompt'),
         score    => 1,
      });

      $c->model("DB::PromptVote")->create({
         user_id => $c->user->id,
         prompt_id => $prompt->id,
         value => 1,
      });

      $c->stash->{status_msg} = 'Submission successful';
   }
}

sub delete :Chained('fetch') :PathPart('delete') :Args(0) {
   my ( $self, $c ) = @_;

   $c->detach('/forbidden', [ $c->string('cantDelete') ]) unless
      $c->stash->{prompt}->is_manipulable_by( $c->user );

   $c->stash(
      key => $c->stash->{prompt}->contents,
      header => $c->string('confirmDeletion'),
      confirmPrompt => $c->string('confirmPrompt', $c->string('contents')),
   );

   $c->forward('do_delete') if $c->req->method eq 'POST';

   push @{ $c->stash->{title} }, $c->string('delete');
   $c->stash->{template} = 'root/confirm.tt';
}

sub do_delete :Private {
   my ( $self, $c ) = @_;

   $c->forward('/check_csrf_token');

   $c->log->info( sprintf "Prompt deleted by %s: %s by %s",
      $c->user->name,
      $c->stash->{prompt}->contents,
      $c->stash->{prompt}->user->name,
   );

   $c->stash->{prompt}->delete;

   $c->flash->{status_msg} = 'Deletion successful';
   $c->res->redirect($c->req->param('referer') || $c->uri_for('/'));
}

=head1 AUTHOR

Cameron Thornton

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
