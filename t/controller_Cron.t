use strict;
use warnings;
use Test::More;


use Catalyst::Test 'WriteOff';
use WriteOff::Controller::Cron;

ok( request('/cron')->is_success, 'Request should succeed' );
done_testing();
