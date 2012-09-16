Installation
============

- `WriteOff$ cp writeoff.conf.template writeoff.conf`
  - Fill in the details as appropriate
- `WriteOff$ sqlite3 WriteOff.db < dbschema.sql`
  - If you want to use another Database, change lib/Model/DB.pm to include the appropriate connection details. See the DBIC POD for more details.
- `WriteOff$ perl Makefile.pl`
- `WriteOff$ script/writeoff_add_user.pl admin admin admin`
  - Adds an admin account; you can change the password through the app later.
- `WriteOff$ script/writeoff_server.pl`

