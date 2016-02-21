CREATE TABLE votes_tmp (
  id INTEGER,
  ballot_id INTEGER,
  story_id INTEGER,
  image_id INTEGER,
  value INTEGER,
  abstained INTEGER);

CREATE TABLE ballots_tmp (
  id INTEGER,
  event_id INTEGER,
  user_id INTEGER,
  round TEXT,
  mode TEXT,
  created TIMESTAMP,
  updated TIMESTAMP);

.read 'data/writeoff-votes.sql'

DELETE FROM votes;
DELETE FROM ballots;

INSERT INTO votes
SELECT id, ballot_id, (SELECT id FROM entrys e WHERE e.story_id=tmp.story_id OR e.image_id=tmp.image_id), value, abstained
FROM votes_tmp tmp;

INSERT INTO ballots
SELECT
  id, event_id,
  (SELECT id FROM rounds r
    WHERE r.event_id=ballots_tmp.event_id
    AND r.mode=ballots_tmp.mode
    AND r.name=ballots_tmp.round),
  user_id, NULL, created, updated
FROM ballots_tmp;

DROP TABLE votes_tmp;
DROP TABLE ballots_tmp;
