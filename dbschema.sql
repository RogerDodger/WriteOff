------
-- Schema for the application's database
-- Author: Cameron Thornton <cthor@cpan.org>
------

PRAGMA foreign_keys = ON;

DROP TABLE IF EXISTS votes;
DROP TABLE IF EXISTS vote_records;
DROP TABLE IF EXISTS heats;
DROP TABLE IF EXISTS prompts;
DROP TABLE IF EXISTS image_story;
DROP TABLE IF EXISTS images;
DROP TABLE IF EXISTS storys;
DROP TABLE IF EXISTS events;
DROP TABLE IF EXISTS user_role;
DROP TABLE IF EXISTS users;
DROP TABLE IF EXISTS roles;

-- User tables
CREATE TABLE users (
	id          INTEGER PRIMARY KEY,
	username    TEXT UNIQUE,
	password    TEXT,
	email       TEXT UNIQUE,
	timezone    TEXT DEFAULT 'UTC',
	ip          TEXT,
	verified    INTEGER DEFAULT 0,
	token       TEXT,
	created     TIMESTAMP,
	active      INTEGER
);

CREATE TABLE roles (
	id   INTEGER PRIMARY KEY,
	role TEXT
);

INSERT INTO roles VALUES (1, 'admin');
INSERT INTO roles VALUES (2, 'user');

CREATE TABLE user_role (
	user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
	role_id INTEGER REFERENCES roles(id) ON DELETE CASCADE,
	PRIMARY KEY (user_id, role_id)
);


-- Event tables
CREATE TABLE events (
	id             INTEGER PRIMARY KEY,
	prompt         TEXT DEFAULT 'TBD',
	has_art        INTEGER,
	has_prelim     INTEGER,
	'start'        TIMESTAMP,
	prompt_voting  TIMESTAMP,
	art            TIMESTAMP,
	art_end        TIMESTAMP,
	fic            TIMESTAMP,
	fic_end        TIMESTAMP,
	prelims        TIMESTAMP,
	finals         TIMESTAMP,
	'end'          TIMESTAMP,
	created        TIMESTAMP
);

CREATE TABLE heats (
	id       INTEGER PRIMARY KEY,
	"left"   INTEGER REFERENCES prompts(id) ON DELETE CASCADE,
	"right"  INTEGER REFERENCES prompts(id) ON DELETE CASCADE,
	created  TIMESTAMP
);

-- Resource tables
CREATE TABLE prompts (
	id        INTEGER PRIMARY KEY,
	event_id  INTEGER REFERENCES events(id) ON DELETE CASCADE,
	user_id   INTEGER REFERENCES users(id) ON DELETE CASCADE,
	contents  TEXT,
	rating    INTEGER
);

CREATE TABLE storys (
	id         INTEGER PRIMARY KEY,
	event_id   INTEGER REFERENCES events(id) ON DELETE CASCADE,
	user_id    INTEGER REFERENCES users(id) ON DELETE CASCADE,
	title      TEXT UNIQUE,
	author     TEXT,
	website    TEXT,
	contents   TEXT,
	wordcount  INTEGER,
	created    TIMESTAMP,
	updated    TIMESTAMP
);

CREATE TABLE images (
	id        INTEGER PRIMARY KEY,
	filesize  INTEGER,
	mime      TEXT,
	event_id  INTEGER REFERENCES events(id) ON DELETE CASCADE,
	user_id   INTEGER REFERENCES users(id) ON DELETE CASCADE,
	title     TEXT UNIQUE,
	artist    TEXT,
	website   TEXT,
	image     BLOB,
	thumb     BLOB,
	created   TIMESTAMP
);

CREATE TABLE image_story (
	image_id  INTEGER REFERENCES images(id) ON DELETE CASCADE,
	story_id  INTEGER REFERENCES storys(id) ON DELETE CASCADE,
	PRIMARY KEY (image_id, story_id)
);

CREATE TABLE vote_records (
	id        INTEGER PRIMARY KEY,
	event_id  INTEGER REFERENCES events(id) ON DELETE CASCADE,
	user_id   INTEGER REFERENCES users(id) ON DELETE SET NULL,
	ip        TEXT,
	created   TIMESTAMP,
	UNIQUE (event_id, ip),
	UNIQUE (event_id, user_id)
);

CREATE TABLE votes (
	id         INTEGER PRIMARY KEY,
	record_id  INTEGER REFERENCES vote_records(id) ON DELETE CASCADE,
	story_id   INTEGER REFERENCES storys(id) ON DELETE CASCADE,
	rating     INTEGER,
	UNIQUE (record_id, story_id)
);
