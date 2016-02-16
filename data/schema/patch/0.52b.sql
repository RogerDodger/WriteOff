--
-- Insert data into new database
--

SELECT load_extension('bin/libsqlitefunctions.so');

CREATE TABLE ratings_tmp (
	id INTEGER,
	story_id INTEGER,
	image_id INTEGER,
	event_id INTEGER,
	round TEXT,
	mode TEXT,
	value REAL,
	error REAL);

CREATE TABLE awards_tmp (
	id INTEGER,
	story_id INTEGER,
	image_id INTEGER,
	event_id INTEGER,
	artist_id INTEGER,
	award_id INTEGER);

CREATE TABLE votes_tmp (
	id INTEGER,
	ballot_id INTEGER,
	story_id INTEGER,
	image_id INTEGER,
	value INTEGER,
	abstained INTEGER);

CREATE TABLE guesses_tmp (
	id INTEGER,
	theory_id INTEGER,
	story_id INTEGER,
	image_id INTEGER,
	artist_id INTEGER);

CREATE TABLE ballots_tmp (
	id INTEGER,
	event_id INTEGER,
	user_id INTEGER,
	round TEXT,
	mode TEXT,
	created TIMESTAMP,
	updated TIMESTAMP);

.read 'data/writeoff.sql'

INSERT INTO ratings (round_id, entry_id, value, error)
SELECT
	(SELECT id FROM rounds r WHERE r.event_id=tmp.event_id AND r.name=tmp.round AND r.mode=tmp.mode),
	(SELECT id FROM entrys e WHERE e.story_id=tmp.story_id OR e.image_id=tmp.image_id),
	value, error
FROM ratings_tmp tmp;

INSERT INTO votes
SELECT id, ballot_id, (SELECT id FROM entrys e WHERE e.story_id=tmp.story_id OR e.image_id=tmp.image_id), value, abstained
FROM votes_tmp tmp;

INSERT INTO guesses
SELECT id, theory_id, (SELECT id FROM entrys e WHERE e.story_id=tmp.story_id OR e.image_id=tmp.image_id), artist_id
FROM guesses_tmp tmp;

INSERT INTO awards
SELECT id, (SELECT id FROM entrys e WHERE e.story_id=tmp.story_id OR e.image_id=tmp.image_id), award_id
FROM awards_tmp tmp
WHERE award_id != 7;

UPDATE entrys SET
	round_id = (
		SELECT ro.id FROM rounds ro
		LEFT JOIN ratings ra ON ra.round_id=ro.id AND ra.entry_id=entrys.id
		WHERE ro.event_id=entrys.event_id
		AND (ro.mode = 'fic' AND entrys.story_id IS NOT NULL
			OR ro.mode = 'art' AND entrys.image_id IS NOT NULL)
		AND ro.action = 'vote'
		ORDER BY ra.id IS NOT NULL DESC, ro.end ASC
		LIMIT 1),
	score_genre = score * power(0.9, (
		SELECT COUNT(*) FROM events
		WHERE created > (SELECT created FROM events e WHERE e.id=entrys.event_id)
		AND genre_id = (SELECT genre_id FROM events WHERE id=entrys.event_id))),
	score_format = score * power(0.9, (
		SELECT COUNT(*) FROM events
		WHERE created > (SELECT created FROM events e WHERE e.id=entrys.event_id)
		AND genre_id = (SELECT e.genre_id FROM events e WHERE e.id=entrys.event_id)
		AND format_id = (SELECT e.format_id FROM events e WHERE e.id=entrys.event_id)));

INSERT INTO ballots (event_id, round_id, user_id, deviance, created, updated)
SELECT
	event_id,
	(SELECT id FROM rounds r
		WHERE r.event_id=ballots_tmp.event_id
		AND r.mode=ballots_tmp.mode
		AND r.name=ballots_tmp.round),
	user_id, NULL, created, updated
FROM ballots_tmp;

UPDATE events SET content_level='E' WHERE content_level=0;
UPDATE events SET content_level='T' WHERE content_level=1;
UPDATE events SET content_level='M' WHERE content_level=2;

DROP TABLE ratings_tmp;
DROP TABLE votes_tmp;
DROP TABLE guesses_tmp;
DROP TABLE awards_tmp;
DROP TABLE ballots_tmp;
