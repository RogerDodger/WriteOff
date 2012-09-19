------
-- Schema for WriteOff.pm's database
-- Author: Cameron Thornton <cthor@cpan.org>
------

PRAGMA foreign_keys = ON;

DROP TABLE IF EXISTS scoreboard;
DROP TABLE IF EXISTS login_attempts;
DROP TABLE IF EXISTS bans;
DROP TABLE IF EXISTS votes;
DROP TABLE IF EXISTS vote_records;
DROP TABLE IF EXISTS heats;
DROP TABLE IF EXISTS prompts;
DROP TABLE IF EXISTS image_story;
DROP TABLE IF EXISTS images;
DROP TABLE IF EXISTS storys;
DROP TABLE IF EXISTS user_event;
DROP TABLE IF EXISTS events;
DROP TABLE IF EXISTS schedules;
DROP TABLE IF EXISTS user_role;
DROP TABLE IF EXISTS users;
DROP TABLE IF EXISTS roles;

-- User tables
CREATE TABLE users (
	id              INTEGER PRIMARY KEY,
	username        TEXT COLLATE NOCASE UNIQUE NOT NULL,
	password        TEXT NOT NULL,
	email           TEXT COLLATE NOCASE UNIQUE,
	timezone        TEXT DEFAULT 'UTC',
	ip              TEXT,
	verified        INTEGER DEFAULT 0 NOT NULL,
	mailme          INTEGER DEFAULT 0 NOT NULL,
	last_mailed_at  TIMESTAMP,
	token           TEXT,
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

CREATE TABLE bans (
	id       INTEGER PRIMARY KEY,
	ip       TEXT NOT NULL,
	reason   TEXT,
	expires  TIMESTAMP NOT NULL,
	created  TIMESTAMP
);

CREATE TABLE login_attempts (
	id       INTEGER PRIMARY KEY,
	ip       TEXT NOT NULL,
	created  TIMESTAMP
);

-- Event tables
CREATE TABLE events (
	id              INTEGER PRIMARY KEY,
	prompt          TEXT DEFAULT 'TBD' NOT NULL,
	blurb           TEXT,
	wc_min          INTEGER NOT NULL,
	wc_max          INTEGER NOT NULL,
	rule_set        INTEGER DEFAULT 1 NOT NULL,
	"start"         TIMESTAMP NOT NULL,
	prompt_voting   TIMESTAMP NOT NULL,
	art             TIMESTAMP,
	art_end         TIMESTAMP,
	fic             TIMESTAMP NOT NULL,
	fic_end         TIMESTAMP NOT NULL,
	prelim          TIMESTAMP,
	"public"        TIMESTAMP NOT NULL,
	"private"       TIMESTAMP,
	"end"           TIMESTAMP NOT NULL,
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

CREATE TABLE heats (
	id        INTEGER PRIMARY KEY,
	"left"    INTEGER REFERENCES prompts(id) ON DELETE CASCADE NOT NULL,
	"right"   INTEGER REFERENCES prompts(id) ON DELETE CASCADE NOT NULL,
	event_id  INTEGER REFERENCES events(id) ON DELETE CASCADE NOT NULL,
	ip        TEXT,
	created   TIMESTAMP
);

-- Resource tables
CREATE TABLE prompts (
	id        INTEGER PRIMARY KEY,
	event_id  INTEGER REFERENCES events(id) ON DELETE CASCADE NOT NULL,
	user_id   INTEGER REFERENCES users(id) ON DELETE CASCADE,
	ip        TEXT,
	contents  TEXT COLLATE NOCASE NOT NULL,
	rating    REAL DEFAULT 1500 NOT NULL,
	created   TIMESTAMP
);

CREATE TABLE storys (
	id         INTEGER PRIMARY KEY,
	event_id   INTEGER REFERENCES events(id) ON DELETE CASCADE NOT NULL,
	user_id    INTEGER REFERENCES users(id) ON DELETE CASCADE,
	ip         TEXT,
	title      TEXT UNIQUE COLLATE NOCASE NOT NULL,
	author     TEXT DEFAULT 'Anonymous' COLLATE NOCASE NOT NULL,
	website    TEXT,
	contents   TEXT NOT NULL,
	wordcount  INTEGER NOT NULL,
	seed       REAL,
	views      INTEGER DEFAULT 0,
	created    TIMESTAMP,
	updated    TIMESTAMP
);

CREATE TABLE images (
	id        INTEGER PRIMARY KEY,
	event_id  INTEGER REFERENCES events(id) ON DELETE CASCADE NOT NULL,
	user_id   INTEGER REFERENCES users(id) ON DELETE CASCADE,
	ip        TEXT,
	title     TEXT UNIQUE COLLATE NOCASE NOT NULL,
	artist    TEXT DEFAULT 'Anonymous' COLLATE NOCASE NOT NULL,
	website   TEXT,
	contents  BLOB NOT NULL,
	thumb     BLOB NOT NULL,
	filesize  INTEGER NOT NULL,
	mimetype  TEXT NOT NULL,
	seed      REAL,
	created   TIMESTAMP
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
	ip        TEXT,
	"round"   TEXT NOT NULL,
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

CREATE TABLE scoreboard (
	competitor  TEXT COLLATE NOCASE PRIMARY KEY,
	"score"     INTEGER DEFAULT 0 NOT NULL,
	"awards"    TEXT,
	created     TIMESTAMP,
	updated     TIMESTAMP
);