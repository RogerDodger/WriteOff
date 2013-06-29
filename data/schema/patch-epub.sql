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


    ALTER TABLE storys RENAME TO storys_tmp;
    
    CREATE TABLE storys (
        id         INTEGER PRIMARY KEY,
        event_id   INTEGER REFERENCES events(id) ON DELETE CASCADE NOT NULL,
        user_id    INTEGER REFERENCES users(id) ON DELETE CASCADE,
        ip         TEXT,
        title      TEXT COLLATE NOCASE NOT NULL,
        author     TEXT DEFAULT 'Anonymous' COLLATE NOCASE NOT NULL,
        website    TEXT,
        contents   TEXT NOT NULL,
        wordcount  INTEGER NOT NULL,
        seed       REAL,
        views      INTEGER DEFAULT 0,
        is_finalist          BIT DEFAULT 0 NOT NULL,
        is_public_candidate  BIT DEFAULT 0 NOT NULL,
        created    TIMESTAMP,
        updated    TIMESTAMP,
        ebook      BLOB
    );

    INSERT INTO
        storys
    SELECT
        id, event_id, user_id, ip, title, author, website,
        contents, wordcount, seed, views, is_finalist,
        is_public_candidate, created, updated, NULL
    FROM
        storys_tmp;

    DROP TABLE storys_tmp;
COMMIT;
