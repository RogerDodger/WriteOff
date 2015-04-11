
BEGIN TRANSACTION;
	ALTER TABLE artist_award RENAME TO artist_award_tmp;

	CREATE TABLE artist_award (
		id         INTEGER PRIMARY KEY,
		artist_id  INTEGER REFERENCES artists(id) ON DELETE CASCADE NOT NULL,
		event_id   INTEGER REFERENCES events(id) ON DELETE CASCADE NOT NULL,
		story_id   INTEGER REFERENCES storys(id) ON DELETE CASCADE,
		image_id   INTEGER REFERENCES images(id) ON DELETE CASCADE,
		"type"     TEXT,
		award_id   INTEGER NOT NULL
	);

	INSERT INTO
		artist_award
	SELECT
		id, artist_id, event_id, NULL, NULL, type, award_id
	FROM
		artist_award_tmp;

	DROP TABLE artist_award_tmp;
COMMIT;

DROP TABLE awards;
ALTER TABLE artists ADD COLUMN score8 INTEGER;
