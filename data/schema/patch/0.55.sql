DROP TABLE IF EXISTS posts;
CREATE TABLE posts (
  id INTEGER PRIMARY KEY NOT NULL,
  artist_id integer,
  event_id integer,
  entry_id integer,
  body text NOT NULL,
  body_render text NOT NULL,
  created timestamp,
  updated timestamp,
  FOREIGN KEY (artist_id) REFERENCES artists(id),
  FOREIGN KEY (entry_id) REFERENCES entrys(id),
  FOREIGN KEY (event_id) REFERENCES events(id)
);
CREATE INDEX posts_idx_artist_id ON posts (artist_id);
CREATE INDEX posts_idx_entry_id ON posts (entry_id);
CREATE INDEX posts_idx_event_id ON posts (event_id);

ALTER TABLE events ADD COLUMN commenting TEXT NOT NULL DEFAULT 1;
UPDATE events SET commenting=0;
