use utf8;
package WriteOff::Schema;

use warnings;
use strict;
use base 'DBIx::Class::Schema';

require DBI;

__PACKAGE__->load_namespaces;

1;
