use strict;
use warnings;

use WriteOff;

my $app = WriteOff->apply_default_middlewares(WriteOff->psgi_app);
$app;

