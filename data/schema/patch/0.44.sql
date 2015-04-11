CREATE TABLE guesses (
	id         INTEGER PRIMARY KEY,
	record_id  INTEGER REFERENCES vote_records(id) ON DELETE CASCADE NOT NULL,
	story_id   INTEGER REFERENCES storys(id) ON DELETE CASCADE,
	image_id   INTEGER REFERENCES images(id) ON DELETE CASCADE,
	artist_id  INTEGER REFERENCES artists(id) ON DELETE CASCADE
);

ALTER TABLE images ADD COLUMN artist_id REFERENCES artists(id) ON DELETE CASCADE;
ALTER TABLE storys ADD COLUMN artist_id REFERENCES artists(id) ON DELETE CASCADE;

INSERT INTO
	artists (name, user_id)
SELECT
	author, user_id
FROM
	storys
WHERE
	(select count(*) from artists where name=storys.author)=0
GROUP BY
	user_id;

UPDATE images SET artist_id=(select id from artists where name=images.artist);
UPDATE storys SET artist_id=(select id from artists where name=storys.author);

ALTER TABLE vote_records ADD COLUMN score INTEGER;
