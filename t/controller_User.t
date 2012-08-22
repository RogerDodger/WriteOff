use strict;
use warnings;
use Test::More;


use Catalyst::Test 'WriteOff';
use WriteOff::Controller::User;

ok( request('/user')->is_success, 'Request should succeed' );
done_testing();
