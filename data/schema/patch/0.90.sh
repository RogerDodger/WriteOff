#!/bin/bash

cd "$( dirname "$0" )/../../.."

sqlite3 data/WriteOff.db <<SQL
CREATE TABLE users_tmp (
   id integer primary key,
   active_artist_id integer references artists(id),
   name text,
   name_canonical text unique,
   password text,
   email text,
   email_canonical text unique,
   fimfic_id integer unique,
   fimfic_name text,
   verified bit default 0 not null,
   autosub bit default 0 not null,
   font text default "serif" not null,
   created timestamp,
   updated timestamp
);

INSERT INTO users_tmp
SELECT
   id, active_artist_id, name, name_canonical, password, email, email_canonical,
   null, null, verified, autosub, font, created, updated
FROM users;

DROP TABLE users;
ALTER TABLE users_tmp RENAME TO users;
CREATE INDEX users_active_artist_id ON users (active_artist_id);
CREATE INDEX users_name_canonical ON users (name_canonical);
CREATE INDEX users_fimfic_id ON users (fimfic_id);
SQL
