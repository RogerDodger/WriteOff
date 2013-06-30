-- DESCRIPTION
--
-- Schema patch for WriteOff.pm's database to contain epubs
--
-- AUTHOR
--
-- Cameron Thornton <cthor@cpan.org>

BEGIN TRANSACTION;
	ALTER TABLE events RENAME TO events_tmp;

	CREATE TABLE events (
		id              INTEGER PRIMARY KEY,
		prompt          TEXT DEFAULT 'TBD' NOT NULL,
		blurb           TEXT,
		wc_min          INTEGER NOT NULL,
		wc_max          INTEGER NOT NULL,
		rule_set        INTEGER DEFAULT 1 NOT NULL,
		custom_rules    TEXT,
		"start"         TIMESTAMP NOT NULL,
		prompt_voting   TIMESTAMP,
		art             TIMESTAMP,
		art_end         TIMESTAMP,
		fic             TIMESTAMP,
		fic_end         TIMESTAMP,
		prelim          TIMESTAMP,
		"public"        TIMESTAMP,
		"private"       TIMESTAMP,
		"end"           TIMESTAMP NOT NULL,
		created         TIMESTAMP,
        "ebook"         BLOB
	);

	INSERT INTO
		events
	SELECT
		id, prompt, blurb, wc_min, wc_max, rule_set, custom_rules, `start`,
		prompt_voting, art, art_end,
		fic, fic_end, prelim, public, private, end, created, NULL
	FROM
		events_tmp;

	DROP TABLE events_tmp;

COMMIT;
