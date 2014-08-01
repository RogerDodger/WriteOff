DROP TABLE artist_award;
DROP TABLE awards;

CREATE TABLE artist_award (
	id         INTEGER PRIMARY KEY,
	artist_id  INTEGER REFERENCES artists(id) ON DELETE CASCADE NOT NULL,
	event_id   INTEGER REFERENCES events(id) ON DELETE CASCADE NOT NULL,
	story_id   INTEGER REFERENCES storys(id) ON DELETE CASCADE,
	image_id   INTEGER REFERENCES images(id) ON DELETE CASCADE,
	"type"     TEXT,
	award_id   INTEGER NOT NULL
);

ALTER TABLE artists ADD COLUMN score8 INTEGER;
