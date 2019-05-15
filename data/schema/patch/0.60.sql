ALTER TABLE artists ADD COLUMN avatar_id;
ALTER TABLE artists ADD COLUMN bio;

CREATE TABLE artist_links (
   id INTEGER PRIMARY KEY,
   artist_id INTEGER,
   icon TEXT,
   url TEXT,
   FOREIGN KEY (artist_id) REFERENCES artists(id)
);

CREATE INDEX artist_links_idx_artist_id ON artist_links (artist_id);
