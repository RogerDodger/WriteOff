--
-- Extracting data to be inserted into new database
--

-- create and merge into entrys, rounds, and ratings tables
-- split vote_records into ballots (for votes) and theorys (for guesses)
-- rename artist_award to awards
-- merge scores into entrys
-- `abstains` removed from ballot
-- `accuracy` added to theory
-- `round` changed to round_id in ballot
-- `candidate` and `finalist` changed to `round_id` in entry

SELECT load_extension('bin/libsqlitefunctions.so');

.output 'data/writeoff.sql'

.mode insert schedules
SELECT * FROM schedules;

.mode insert formats
SELECT * FROM formats;

.mode insert genres
SELECT * FROM genres;

.mode insert users
SELECT id, (
	SELECT artist_id FROM scores LEFT JOIN artists ON scores.artist_id=artists.id
	WHERE artists.user_id=users.id
	GROUP BY scores.artist_id
	ORDER BY COUNT(artist_id)
	LIMIT 1),
	username, lower(username), password, email, lower(email),
	username='RogerDodger', verified, mailme, created, updated
FROM users;

.mode insert tokens
SELECT NULL,* FROM tokens;

.mode insert artists
SELECT id, user_id, name, IFNULL((SELECT MIN(created) FROM storys WHERE artist_id=artists.id), datetime('now')) FROM artists;

.mode insert events
SELECT id, format_id, genre_id, prompt, blurb, wc_min, wc_max, rule_set,
	custom_rules, guessing, tallied, created, created
FROM events;

.mode insert prompts
SELECT id, event_id, user_id, contents, IFNULL(CAST (rating AS INTEGER), approvals), created FROM prompts;

.mode insert rounds
SELECT NULL, id, 'writing', 'fic', fic, fic_end FROM events WHERE fic IS NOT NULL;
SELECT NULL, id, 'drawing', 'art', art, art_end FROM events WHERE art IS NOT NULL;
SELECT NULL, id, 'prelim', 'vote', prelim, public FROM events WHERE prelim IS NOT NULL;
SELECT NULL, id, 'prelim', 'vote', public, private FROM events WHERE private IS NOT NULL;
SELECT NULL, id, 'final', 'vote', private, end FROM events WHERE private IS NOT NULL;
SELECT NULL, id, 'final', 'vote', public, end FROM events WHERE private IS NULL;

.mode insert user_event
SELECT * FROM user_event;

-- round_id must be determined later
.mode insert entrys
SELECT NULL, event_id, user_id, artist_id, id, NULL, NULL, title, seed, disqualified,
	(SELECT orig FROM scores WHERE storys.id=scores.story_id),
	(SELECT orig FROM scores WHERE storys.id=scores.story_id),
	(SELECT orig FROM scores WHERE storys.id=scores.story_id),
	rank, rank_low, 0, created, updated
FROM storys;

SELECT NULL, event_id, user_id, artist_id, NULL, id, NULL, title, seed, 0,
	(SELECT orig FROM scores WHERE images.id=scores.image_id),
	(SELECT orig FROM scores WHERE images.id=scores.image_id),
	(SELECT orig FROM scores WHERE images.id=scores.image_id),
	rank, rank_low, 0, created, updated
FROM images;

.mode insert storys
SELECT id, contents, wordcount, indexed, published, created, updated FROM storys;

.mode insert images
SELECT id, hovertext, filesize, mimetype, version, created, updated FROM images;

.mode insert image_story
SELECT * from image_story;

-- event_id >= 38 uses twipie
-- event_id >= 35 uses normalised n - 2i (and has no prelim_stdev calculated!)
-- event_id >= 33 has prelim
-- event_id <= 32 with prelim don't have any ratings on prelims
-- event_id IN [3,7,8,9] has judges

UPDATE storys
	SET prelim_stdev=(
		SELECT STDEV(v.percentile)
		FROM votes v LEFT JOIN vote_records r ON r.id=v.record_id
		WHERE r.round='prelim' AND v.story_id=storys.id AND v.value IS NOT NULL)
	WHERE event_id IN (35, 36, 37);

.mode insert ratings_tmp
SELECT NULL, NULL, id, event_id, 'final', public_score, public_stdev
FROM images;

SELECT NULL, id, NULL, event_id, 'prelim', prelim_score, prelim_stdev
FROM storys WHERE prelim_score IS NOT NULL;

SELECT NULL, id, NULL, event_id, 'prelim', public_score, public_stdev
FROM storys WHERE public_score IS NOT NULL AND event_id IN (3,7,8,9);

SELECT NULL, id, NULL, event_id, 'final', public_score, NULLIF(public_stdev, 0)
FROM storys WHERE public_score IS NOT NULL AND event_id NOT IN (3,7,8,9);

SELECT NULL, id, NULL, event_id, 'final', private_score, NULL
FROM storys WHERE private_score IS NOT NULL;

-- award
-- ballot
-- vote
-- theory
-- guess

.mode insert awards_tmp
SELECT id, story_id, image_id, event_id, artist_id, award_id FROM artist_award;

.mode insert ballots
SELECT id, event_id, user_id, 'prelim', type, NULL, created, updated
FROM vote_records WHERE round = 'prelim';

SELECT id, event_id, user_id, 'final', type, NULL, created, updated
FROM vote_records WHERE round = 'private';

SELECT id, event_id, user_id, 'final', type, NULL, created, updated
FROM vote_records WHERE round = 'public' AND event_id IN (3,7,8,9);

SELECT id, event_id, user_id, 'prelim', type, NULL, created, updated
FROM vote_records WHERE round = 'public' AND event_id NOT IN (3,7,8,9);

.mode insert votes_tmp
SELECT id, record_id, story_id, image_id, value, abstained FROM votes;

.mode insert theorys
SELECT id, event_id, user_id, artist_id, (
	SELECT award_id
	FROM artist_award a
	LEFT JOIN vote_records ir
		ON ir.event_id=a.event_id
		AND ir.artist_id=a.artist_id
	WHERE ir.event_id=r.event_id
	AND ir.artist_id=r.artist_id
	AND award_id=7),
	NULL, created, updated FROM vote_records r WHERE round = 'guess';

.mode insert guesses_tmp
SELECT id, record_id, story_id, image_id, artist_id FROM guesses;
