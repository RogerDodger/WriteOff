-- DESCRIPTION
--
-- Schema for WriteOff.pm's database
--
-- AUTHOR
--
-- Cameron Thornton <cthor@cpan.org>

PRAGMA foreign_keys = ON;

-- ===========================================================================
-- User stuff
-- ===========================================================================

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

CREATE TABLE roles (
	id   INTEGER PRIMARY KEY,
	role TEXT NOT NULL
);

INSERT INTO roles VALUES (1, 'admin');
INSERT INTO roles VALUES (2, 'user');

CREATE TABLE user_role (
	user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
	role_id INTEGER REFERENCES roles(id) ON DELETE CASCADE,
	PRIMARY KEY (user_id, role_id)
);

CREATE TABLE tokens (
	user_id   INTEGER REFERENCES users(id) ON DELETE CASCADE NOT NULL,
	"type"    TEXT NOT NULL,
	value     TEXT NOT NULL,
	address   TEXT,
	expires   TIMESTAMP NOT NULL,
	PRIMARY KEY (user_id, "type")
);

CREATE TABLE bans (
	id       INTEGER PRIMARY KEY,
	ip       TEXT NOT NULL,
	reason   TEXT,
	expires  TIMESTAMP NOT NULL,
	created  TIMESTAMP
);

-- ===========================================================================
-- Event stuff
-- ===========================================================================

CREATE TABLE events (
	id              INTEGER PRIMARY KEY,
	prompt          TEXT DEFAULT 'TBD' NOT NULL,
	prompt_type     TEXT DEFAULT 'faceoff',
	blurb           TEXT,
	wc_min          INTEGER NOT NULL,
	wc_max          INTEGER NOT NULL,
	rule_set        INTEGER DEFAULT 1 NOT NULL,
	custom_rules    TEXT,
	guessing        BIT DEFAULT 1 NOT NULL,
	art             TIMESTAMP,
	art_end         TIMESTAMP,
	fic             TIMESTAMP,
	fic_end         TIMESTAMP,
	prelim          TIMESTAMP,
	"public"        TIMESTAMP,
	"private"       TIMESTAMP,
	"end"           TIMESTAMP NOT NULL,
	tallied         BIT DEFAULT 0 NOT NULL,
	created         TIMESTAMP
);

CREATE TABLE user_event (
	user_id   INTEGER REFERENCES users(id)  ON DELETE CASCADE,
	event_id  INTEGER REFERENCES events(id) ON DELETE CASCADE,
	role      TEXT,
	PRIMARY KEY (user_id, event_id, role)
);

CREATE TABLE schedules (
	id      INTEGER PRIMARY KEY,
	action  TEXT NOT NULL,
	"at"    TIMESTAMP NOT NULL,
	args    TEXT
);

-- ===========================================================================
-- Entries
-- ===========================================================================

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

CREATE TABLE heats (
	id        INTEGER PRIMARY KEY,
	"left"    INTEGER REFERENCES prompts(id) ON DELETE CASCADE NOT NULL,
	"right"   INTEGER REFERENCES prompts(id) ON DELETE CASCADE NOT NULL,
	ip        TEXT,
	created   TIMESTAMP
);

CREATE TABLE storys (
	id             INTEGER PRIMARY KEY,
	event_id       INTEGER REFERENCES events(id) ON DELETE CASCADE NOT NULL,
	user_id        INTEGER REFERENCES users(id) ON DELETE CASCADE,
	artist_id      INTEGER REFERENCES artists(id) ON DELETE CASCADE,
	ip             TEXT,
	title          TEXT COLLATE NOCASE NOT NULL,
	website        TEXT,
	contents       TEXT NOT NULL,
	wordcount      INTEGER NOT NULL,
	seed           REAL,
	views          INTEGER DEFAULT 0,
	finalist       BIT DEFAULT 0 NOT NULL,
	candidate      BIT DEFAULT 0 NOT NULL,
	private_score  INTEGER,
	public_score   REAL,
	public_stdev   REAL,
	rank           INTEGER,
	rank_low       INTEGER,
	created        TIMESTAMP,
	updated        TIMESTAMP
);

CREATE TABLE images (
	id            INTEGER PRIMARY KEY,
	event_id      INTEGER REFERENCES events(id) ON DELETE CASCADE NOT NULL,
	user_id       INTEGER REFERENCES users(id) ON DELETE CASCADE,
	artist_id     INTEGER REFERENCES artists(id) ON DELETE CASCADE,
	ip            TEXT,
	title         TEXT COLLATE NOCASE NOT NULL,
	website       TEXT,
	version       TEXT,
	hovertext     TEXT,
	filesize      INTEGER NOT NULL,
	mimetype      TEXT NOT NULL,
	seed          REAL,
	public_score  REAL,
	public_stdev  REAL,
	rank          INTEGER,
	rank_low      INTEGER,
	created       TIMESTAMP,
	updated       TIMESTAMP
);

CREATE TABLE image_story (
	image_id  INTEGER REFERENCES images(id) ON DELETE CASCADE,
	story_id  INTEGER REFERENCES storys(id) ON DELETE CASCADE,
	PRIMARY KEY (image_id, story_id)
);

CREATE TABLE vote_records (
	id        INTEGER PRIMARY KEY,
	event_id  INTEGER REFERENCES events(id) ON DELETE CASCADE NOT NULL,
	user_id   INTEGER REFERENCES users(id) ON DELETE SET NULL,
	artist_id INTEGER REFERENCES artists(id) ON DELETE SET NULL,
	ip        TEXT,
	"round"   TEXT NOT NULL,
	"type"    TEXT NOT NULL,
	filled    BIT NOT NULL DEFAULT 0,
	score     INTEGER,
	mean      REAL,
	stdev     REAL,
	created   TIMESTAMP,
	updated   TIMESTAMP
);

CREATE TABLE votes (
	id         INTEGER PRIMARY KEY,
	record_id  INTEGER REFERENCES vote_records(id) ON DELETE CASCADE NOT NULL,
	story_id   INTEGER REFERENCES storys(id) ON DELETE CASCADE,
	image_id   INTEGER REFERENCES images(id) ON DELETE CASCADE,
	"value"    INTEGER
);

CREATE TABLE guesses (
	id         INTEGER PRIMARY KEY,
	record_id  INTEGER REFERENCES vote_records(id) ON DELETE CASCADE NOT NULL,
	story_id   INTEGER REFERENCES storys(id) ON DELETE CASCADE,
	image_id   INTEGER REFERENCES images(id) ON DELETE CASCADE,
	artist_id  INTEGER REFERENCES artists(id) ON DELETE CASCADE
);

-- ===========================================================================
-- Scoreboard stuff
-- ===========================================================================

CREATE TABLE artists (
	id       INTEGER PRIMARY KEY,
	name     TEXT COLLATE NOCASE UNIQUE NOT NULL,
	user_id  INTEGER REFERENCES users(id),
	score    INTEGER,
	score8   INTEGER
);

CREATE TABLE artist_award (
	id         INTEGER PRIMARY KEY,
	artist_id  INTEGER REFERENCES artists(id) ON DELETE CASCADE NOT NULL,
	event_id   INTEGER REFERENCES events(id) ON DELETE CASCADE NOT NULL,
	story_id   INTEGER REFERENCES storys(id) ON DELETE SET NULL,
	image_id   INTEGER REFERENCES images(id) ON DELETE SET NULL,
	"type"     TEXT,
	award_id   INTEGER NOT NULL
);

CREATE TABLE scores (
	id         INTEGER PRIMARY KEY,
	artist_id  INTEGER REFERENCES artists(id) ON DELETE CASCADE NOT NULL,
	event_id   INTEGER REFERENCES events(id) ON DELETE CASCADE NOT NULL,
	story_id   INTEGER REFERENCES storys(id) ON DELETE SET NULL,
	image_id   INTEGER REFERENCES images(id) ON DELETE SET NULL,
	"type"     TEXT,
	"value"    REAL,
	orig       REAL
);

-- ===========================================================================
-- Misc
-- ===========================================================================

CREATE TABLE news (
	id       INTEGER PRIMARY KEY,
	user_id  INTEGER REFERENCES users(id) ON DELETE SET NULL,
	title    TEXT,
	body     TEXT,
	created  TIMESTAMP,
	updated  TIMESTAMP
);
