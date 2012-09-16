Installation
============

- `WriteOff$ cp writeoff.conf.template writeoff.conf` - Fill in the details as appropriate
- `WriteOff$ sqlite3 WriteOff.db < dbschema.sql`
- `WriteOff$ perl Makefile.pl`
- `WriteOff$ script/writeoff_add_user.pl admin admin admin`
- `WriteOff$ script/writeoff_server.pl`

If you want to use a database other than sqlite, change `lib/Model/DB.pm` to include the appropriate connection details. See the DBIC POD for more details.
