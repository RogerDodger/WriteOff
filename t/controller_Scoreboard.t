use strict;
use warnings;
use Test::More;


use Catalyst::Test 'WriteOff';
use WriteOff::Controller::Scoreboard;

ok( request('/scoreboard')->is_success, 'Request should succeed' );
done_testing();
