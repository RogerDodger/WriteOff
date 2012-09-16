use strict;
use warnings;
use Test::More;


use Catalyst::Test 'WriteOff';
use WriteOff::Controller::Vote;

ok( request('/vote')->is_success, 'Request should succeed' );
done_testing();
