-- DESCRIPTION
--
-- Schema patch for WriteOff.pm's database from 0.35 to 0.36
--
-- AUTHOR
--
-- Cameron Thornton <cthor@cpan.org>

DROP TABLE login_attempts;

BEGIN TRANSACTION;
	ALTER TABLE users RENAME TO users_tmp;

	CREATE TABLE users (
		id              INTEGER PRIMARY KEY,
		username        TEXT COLLATE NOCASE UNIQUE NOT NULL,
		password        TEXT NOT NULL,
		email           TEXT COLLATE NOCASE UNIQUE,
		timezone        TEXT DEFAULT 'UTC',
		ip              TEXT,
		verified        INTEGER DEFAULT 0 NOT NULL,
		mailme          INTEGER DEFAULT 0 NOT NULL,
		created         TIMESTAMP,
		updated         TIMESTAMP
	);

	INSERT INTO
		users
	SELECT
		id, username, password, email, timezone, ip,
		verified, mailme, created, updated
	FROM
		users_tmp;

	DROP TABLE users_tmp;
COMMIT;

CREATE TABLE tokens (
	user_id   INTEGER REFERENCES users(id) NOT NULL,
	"type"    TEXT NOT NULL,
	value     TEXT NOT NULL,
	address   TEXT,
	expires   TIMESTAMP NOT NULL,
	PRIMARY KEY (user_id, "type")
);
