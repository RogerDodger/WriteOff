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
      if ($c->stash->{event}->prompt_votes_opened) {
         $c->forward('do_vote') if $c->req->method eq 'POST';
      }

      $c->stash->{votes} = {
         map { $_->prompt_id => $_->value }
            $c->stash->{event}->prompts->related_resultset('votes')->search({
               "votes.user_id" => $c->user->id,
            })
      };
   }

   $c->title_psh('vote');
   $c->stash->{template} = 'prompt/vote.tt';
}

sub do_vote :Private {
   my ( $self, $c ) = @_;

   $c->csrf_assert;

   $c->stash->{event}->prompts->related_resultset('votes')
                              ->search({ "votes.user_id" => $c->user->id })
                              ->delete;

   # my $oldVotes = $c->stash->{event}->prompts->related_resultset('votes')
   #                                           ->search({ "votes.user_id" => $c->user->id });
   # my %oldVals = map { $_->prompt_id => $_->value } $oldVotes->all;
   # $oldVotes->delete;

   my $max = $#{ $c->stash->{labels} };
   my $uid = $c->user->id;
   my $default = $c->stash->{default};

   $c->model('DB::PromptVote')->populate([
      map {
         my $v = $c->parami('prompt' . $_->id);
         my $val = $c->parami('prompt' . $_->id);
            $val = $val >= 0 && $val <= $max ? $val : $default;

         # my $old = $oldVals{$_->id} // 0;
         # $_->update({ score => $_->score + $val - $old }) if $val != $old;

         {
            prompt_id => $_->id,
            user_id => $uid,
            value => $val >= 0 && $val <= $max ? $v : $default,
         }
      } $c->stash->{event}->prompts
   ]);

   # Commented out code above does this update in a smart way, but the
   # performance difference isn't significant enough to worry about it, and
   # this is more guaranteed to be correct.
   $c->model('DB')->schema->storage->dbh_do(
      sub {
         my ($s, $dbh, $eid) = @_;
         $dbh->do(
            q{
               UPDATE prompts
               SET score=(SELECT SUM(value) FROM prompt_votes WHERE prompt_id=prompts.id)
               WHERE event_id=?
            },
            undef,
            $eid
         );
      },
      $c->stash->{event}->id,
   );

   if ($c->stash->{ajax}) {
      $c->res->body($c->string('voteUpdated'));
   }
   else {
      $c->flash->{status_msg} = $c->string('voteUpdated');
      $c->res->redirect($c->req->uri);
   }
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
      && $c->stash->{event}->prompt_subs_opened;

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
         score    => $#{ $c->stash->{labels} },
      });

      $c->model("DB::PromptVote")->create({
         user_id => $c->user->id,
         prompt_id => $prompt->id,
         value => $#{ $c->stash->{labels} },
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

sub results :Chained('/event/prompt') :PathPart('results') :Args(0) {
   my ($self, $c) = @_;

   $c->stash->{prompts} = $c->stash->{event}->prompts->order_by([
      { -desc => 'score' },
      { -asc => 'contents' },
   ]);

   pop @{ $c->stash->{title} };
   $c->title_psh('promptResults');
}

=head1 AUTHOR

Cameron Thornton

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
