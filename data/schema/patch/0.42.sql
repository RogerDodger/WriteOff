DROP TABLE scores;

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
