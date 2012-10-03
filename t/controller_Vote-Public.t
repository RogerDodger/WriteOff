use strict;
use warnings;
use Test::More;


use Catalyst::Test 'WriteOff';
use WriteOff::Controller::Vote::Public;

ok( request('/vote/public')->is_success, 'Request should succeed' );
done_testing();
