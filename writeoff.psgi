use strict;
use warnings;

use FindBin '$Bin';
use lib "$Bin/lib";
use WriteOff;

my $app = WriteOff->apply_default_middlewares(WriteOff->psgi_app);
$app;
