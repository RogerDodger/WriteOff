CREATE TABLE guesses (
	id         INTEGER PRIMARY KEY,
	record_id  INTEGER REFERENCES vote_records(id) ON DELETE CASCADE NOT NULL,
	artist_id  INTEGER REFERENCES artists(id) ON DELETE CASCADE NOT NULL,
	story_id   INTEGER REFERENCES storys(id) ON DELETE CASCADE,
	image_id   INTEGER REFERENCES images(id) ON DELETE CASCADE
);

ALTER TABLE images ADD COLUMN artist_id REFERENCES artists(id) ON DELETE CASCADE;
ALTER TABLE storys ADD COLUMN artist_id REFERENCES artists(id) ON DELETE CASCADE;

UPDATE images SET artist_id=(select id from artists where name=storys.artist);
UPDATE storys SET artist_id=(select id from artists where name=storys.author);
