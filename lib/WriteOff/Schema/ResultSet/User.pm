package WriteOff::Schema::ResultSet::User;

use strict;
use base 'WriteOff::Schema::ResultSet';

sub with_stats {
	my $self = shift;

	my $prompts = $self->result_source->schema->resultset('Prompt')->search(
		{ 'prompts.user_id' => { '=' => { -ident => 'me.id' } } },
		{
			select => [{ avg => 'prompts.rating' }],
			alias => 'prompts',
		}
	);

	my $public = $self->result_source->schema->resultset('Vote')->search(
		{
			'record.user_id' => { '=' => { -ident => 'me.id' } },
			'record.round' => 'public',
		},
		{
			join => 'record',
			select => [{ avg => 'votes.value' }],
			alias => 'votes',
		}
	);

	return $self->search_rs(undef, {
		'+select' => [
			{ '' => $prompts->as_query, -as => 'prompt_skill' },
			{ '' => $public->as_query, -as => 'hugbox_score' },
		],
		'+as' => [ 'prompt_skill', 'hugbox_score' ],
	});
}

sub resolve {
	#TODO
	my ($self, $user) = @_;
	return 0 unless $user;

	return $user->get_object if eval
		{ $user->isa('Catalyst::Authentication::Store::DBIx::Class::User') };

	return $user if eval { $user->isa('WriteOff::Model::DB::User') };
	return $self->find($user) || 0;
}

sub verified {
	return shift->search_rs({ verified => 1 });
}

sub unverified {
	return shift->search_rs({ verified => 0 });
}

sub mailing_list {
	return shift->search_rs({
		mailme   => 1,
		verified => 1,
	});
}

sub clean_unverified {
	my $self = shift;

	$self->search({ verified => 0 })
		->created_before( DateTime->now->subtract( days => 1 ) )
		->delete_all;
}

1;
