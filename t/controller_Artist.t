use strict;
use warnings;
use Test::More;


use Catalyst::Test 'WriteOff';
use WriteOff::Controller::Artist;

ok( request('/artist')->is_success, 'Request should succeed' );
done_testing();
