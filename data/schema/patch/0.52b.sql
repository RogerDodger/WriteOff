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

.read 'data/writeoff.sql'

INSERT INTO ratings (round_id, entry_id, value, error)
SELECT
	(SELECT id FROM rounds r WHERE r.event_id=tmp.event_id AND r.name=tmp.round),
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
	round_id = IFNULL(
		(SELECT ro.id FROM rounds ro LEFT JOIN ratings ra ON ro.id=ra.round_id WHERE ra.entry_id=entrys.id ORDER BY ro.end DESC LIMIT 1),
		(SELECT id FROM rounds WHERE event_id=entrys.event_id ORDER BY end ASC LIMIT 1)),
	score_genre = score * power(0.9, (
		SELECT COUNT(*) FROM events
		WHERE created > (SELECT created FROM events e WHERE e.id=entrys.event_id)
		AND genre_id = (SELECT genre_id FROM events WHERE id=entrys.event_id))),
	score_format = score * power(0.9, (
		SELECT COUNT(*) FROM events
		WHERE created > (SELECT created FROM events e WHERE e.id=entrys.event_id)
		AND genre_id = (SELECT e.genre_id FROM events e WHERE e.id=entrys.event_id)
		AND format_id = (SELECT e.format_id FROM events e WHERE e.id=entrys.event_id)));

INSERT INTO entrys (title, artist_id, event_id, seed)
SELECT "Author guessing", artist_id, event_id, 0.0001
FROM awards_tmp tmp
WHERE award_id = 7;

INSERT INTO awards
SELECT NULL, id, 7
FROM entrys
WHERE (story_id AND image_id) IS NULL;

UPDATE ballots SET round_id = (SELECT id FROM rounds r WHERE r.event_id=ballots.event_id AND r.name=ballots.round_id);

DROP TABLE ratings_tmp;
DROP TABLE votes_tmp;
DROP TABLE guesses_tmp;
DROP TABLE awards_tmp;
