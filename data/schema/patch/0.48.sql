ALTER TABLE storys ADD COLUMN disqualified BIT DEFAULT 0 NOT NULL;
ALTER TABLE images ADD COLUMN disqualified BIT DEFAULT 0 NOT NULL;

UPDATE storys
SET disqualified = 1
WHERE event_id = 36
-- AND

DELETE FROM votes
WHERE story_id IN (
	SELECT id FROM storys WHERE disqualified = 1
);

DELETE FROM guesses
WHERE story_id IN (
	SELECT id FROM storys WHERE disqualified = 1
);

-- Unrelated thing
UPDATE storys SET controversial = controversial / 10 WHERE event_id = 33;
