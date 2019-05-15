ALTER TABLE artists ADD COLUMN updated TIMESTAMP;
UPDATE artists SET updated=created;

CREATE TABLE post_votes (
   post_id INTEGER,
   artist_id INTEGER,
   FOREIGN KEY (post_id) REFERENCES posts(id)
   FOREIGN KEY (artist_id) REFERENCES artists(id)
   PRIMARY KEY (post_id, artist_id)
);

CREATE INDEX post_votes_idx_post_id ON post_votes (post_id);
CREATE INDEX post_votes_idx_artist_id ON post_votes (artist_id);
