Installation
============

- `WriteOff$ cp _writeoff.yml writeoff.yml` - Fill in the configuration as appropriate
- `WriteOff$ sqlite3 WriteOff.db < data/schema/fresh.sql`
- `WriteOff$ perl Makefile.pl`
- `WriteOff$ make`
- `WriteOff$ make test`
- `WriteOff$ make install`
- `WriteOff$ ./script/writeoff_user_add.pl admin admin admin` - Change password in the application
- `WriteOff$ ./script/writeoff_server.pl`

If you want to use a database other than sqlite, change `lib/Model/DB.pm` to include the appropriate connection details. See the DBIC POD for more details.
