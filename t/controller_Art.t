use strict;
use warnings;
use Test::More;


use Catalyst::Test 'WriteOff';
use WriteOff::Controller::Art;

ok( request('/art')->is_success, 'Request should succeed' );
done_testing();
