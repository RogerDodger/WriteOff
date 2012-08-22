use strict;
use warnings;
use Test::More;


use Catalyst::Test 'WriteOff';
use WriteOff::Controller::Fic;

ok( request('/fic')->is_success, 'Request should succeed' );
done_testing();
