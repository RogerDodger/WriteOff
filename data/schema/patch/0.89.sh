#!/bin/bash

cd "$( dirname "$0" )/../../.."

sqlite3 data/WriteOff.db <<SQL
ALTER TABLE events ADD COLUMN cancelled BIT DEFAULT 0;
ALTER TABLE events ADD COLUMN start TIMESTAMP DEFAULT '9999-01-01 00:00:00';
UPDATE events SET start=(SELECT MIN(start) FROM rounds WHERE event_id=events.id);
UPDATE events SET cancelled=1 WHERE id=130;
DELETE FROM rounds WHERE event_id=130;
SQL
