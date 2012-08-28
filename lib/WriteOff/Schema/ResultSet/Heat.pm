package WriteOff::Schema::ResultSet::Heat;

use strict;
use base 'DBIx::Class::ResultSet';
use constant {
	CLEAN_TIMER => 5, #minutes
	ELO_K       => WriteOff->config->{elo}->{k},
	ELO_BETA    => WriteOff->config->{elo}->{beta},
};

sub new_heat {
	my ($self, $prompts, $rng) = @_;
	
	my $n = $prompts->count;
	return 0 if $n < 2;
	
	my $rand = sub { int $rng->rand * $n };
	
	my ($left, $right) = map { $rand->() } 0..1;
	$left = $rand->() while $right == $left;
	
	$prompts = [$prompts->all];
	
	return $self->create({
		left  => $prompts->[$left]->id,
		right => $prompts->[$right]->id,
	});
}

sub do_heat {
	my ($self, $result) = @_;
	#$result = ( left => 1, tie => 0.5, right => 0 );
	
	return "Invalid result" unless defined $result;
	return "Invalid heat" unless $self->count;
	
	my $row = $self->first;
	
	my @R = ($row->left->rating, $row->right->rating);
	
	#         R_a/$beta
	# Q_a = 10^
	my @Q = map { 10**( $R[$_] / ELO_BETA ) } 0..1;
	
	# E_a = Q_a / 
	#     Q_a + Q_b
	my @E = map { $Q[$_] / ( $Q[0]+$Q[1] ) } 0..1;
	
	# S_winner = 1; S_loser = 0; S_tie = 0.5
	my @S = map { abs( $result - $_ ) } 0..1;
	
	# R_new_a = R_a + K(S_a-E_a)
	   @R = map { $R[$_] + ELO_K * ( $S[$_] - $E[$_] ) } 0..1;
	
	$row->left->update ({ rating => $R[0] });
	$row->right->update({ rating => $R[1] });
	
	0;
}

sub created_before {
    my ($self, $datetime) = @_;

    my $date_str = $self->result_source->schema->storage
		->datetime_parser->format_datetime($datetime);

    return $self->search({ created => { '<' => $date_str } });
}

sub clean_old_entries {
	my($self) = @_;
	
	$self->created_before( DateTime->now->subtract(minutes => CLEAN_TIMER) )
		->delete_all;
}

1;
