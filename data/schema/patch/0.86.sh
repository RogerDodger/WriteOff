#!/bin/bash

cd "$( dirname "$0" )/../../.."

sqlite3 data/WriteOff.db <<SQL
DROP TABLE email_triggers;

CREATE TABLE sub_modes (
	user_id integer references users(id),
	mode_id integer,
	primary key (user_id, mode_id)
);
INSERT INTO sub_modes
SELECT me.id, 1
FROM users me
WHERE 0 != (SELECT COUNT(*) FROM sub_formats WHERE user_id=me.id)
AND 0 != (SELECT COUNT(*) FROM sub_genres WHERE user_id=me.id)
AND 0 != (SELECT COUNT(*) FROM sub_triggers WHERE user_id=me.id)
SQL
