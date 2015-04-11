ALTER TABLE events ADD COLUMN guessing BIT DEFAULT 1 NOT NULL;

UPDATE events SET guessing = (end > datetime('now'));

ALTER TABLE vote_records ADD COLUMN
	artist_id  INTEGER REFERENCES artists(id) ON DELETE CASCADE;
