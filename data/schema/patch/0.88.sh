#!/bin/bash

cd "$( dirname "$0" )/../../.."

sqlite3 data/WriteOff.db <<SQL
PRAGMA legacy_alter_table=ON;

CREATE TABLE images_new (
   id INTEGER PRIMARY KEY NOT NULL,
   hovertext text,
   filesize integer NOT NULL,
   mimetype text NOT NULL,
   version text NOT NULL,
   created timestamp,
   updated timestamp
);

INSERT INTO images_new SELECT * FROM images;
DROP TABLE images;
ALTER TABLE images_new RENAME TO images;
SQL
