#!/bin/bash

#Make sure this is called from .../WriteOff

sqlite3 schema.db < dbschema.sql

./script/writeoff_create.pl model DB DBIC::Schema WriteOff::Schema create=static components=TimeStamp,PassphraseColumn,InflateColumn::Serializer dbi:SQLite:schema.db sqlite_unicode=1 on_connect_do="PRAGMA foreign_keys = ON"

rm schema.db
