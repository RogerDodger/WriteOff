-- DESCRIPTION
--
-- Schema patch for WriteOff.pm's database from 0.37 to 0.38
--
-- AUTHOR
--
-- Cameron Thornton <cthor@cpan.org>

BEGIN TRANSACTION;
	ALTER TABLE events RENAME TO events_tmp;

	CREATE TABLE events (
		id              INTEGER PRIMARY KEY,
		prompt          TEXT DEFAULT 'TBD' NOT NULL,
		prompt_type     TEXT DEFAULT 'faceoff',
		blurb           TEXT,
		wc_min          INTEGER NOT NULL,
		wc_max          INTEGER NOT NULL,
		rule_set        INTEGER DEFAULT 1 NOT NULL,
		custom_rules    TEXT,
		art             TIMESTAMP,
		art_end         TIMESTAMP,
		fic             TIMESTAMP,
		fic_end         TIMESTAMP,
		prelim          TIMESTAMP,
		"public"        TIMESTAMP,
		"private"       TIMESTAMP,
		"end"           TIMESTAMP NOT NULL,
		created         TIMESTAMP
	);

	INSERT INTO
		events
	SELECT
		id, prompt, (CASE WHEN prompt_voting THEN 'faceoff' ELSE NULL END),
		blurb, wc_min, wc_max, rule_set, custom_rules, art, art_end, fic,
		fic_end, prelim, "public", "private", "end", created
	FROM
		events_tmp;

	DROP TABLE events_tmp;
COMMIT;

BEGIN TRANSACTION;
	ALTER TABLE prompts RENAME TO prompts_tmp;

	CREATE TABLE prompts (
		id         INTEGER PRIMARY KEY,
		event_id   INTEGER REFERENCES events(id) ON DELETE CASCADE NOT NULL,
		user_id    INTEGER REFERENCES users(id) ON DELETE CASCADE,
		ip         TEXT,
		contents   TEXT COLLATE NOCASE NOT NULL,
		rating     REAL,
		approvals  INTEGER,
		created    TIMESTAMP
	);

	INSERT INTO
		prompts (id, event_id, user_id, ip, contents, rating, created)
	SELECT
		*
	FROM
		prompts_tmp;

	DROP TABLE prompts_tmp;
COMMIT;
