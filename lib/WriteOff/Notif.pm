package WriteOff::Notif;

use v5.14;
use warnings;
use Carp;
use Exporter;

my @notifs;

BEGIN {
	# Order of this array is immutable -- IDs must be persistent
	@notifs = qw/COMMENT REPLY MENTION/;

	my $i = 0;
	for my $notif (@notifs) {
		$i++;
		eval qq{
			use constant _$notif => $i;
			sub $notif () {
				return __PACKAGE__->new(_$notif);
			}
		};
	}
}

our @ISA = qw/Exporter/;
our @EXPORT_OK = ( @notifs );
our %EXPORT_TAGS = ( all => \@EXPORT_OK );

my %attr = (
	_COMMENT() => [ 'notifComment' ],
	_REPLY()   => [ 'notifReply' ],
	_MENTION() => [ 'notifMention' ],
);

sub new {
	my ($class, $id) = @_;

	unless (exists $attr{$id}) {
		Carp::croak "Invalid notif ID: $id";
	}

	return bless \$id, $class;
}

sub id {
	return ${ +shift };
}

sub string {
	$attr{shift->id}->[0];
}

1;
