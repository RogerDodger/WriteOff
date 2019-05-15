ALTER TABLE events ADD COLUMN prompt_fixed TEXT;

ALTER TABLE artists ADD COLUMN admin BIT NOT NULL DEFAULT 0;
ALTER TABLE artists ADD COLUMN mod BIT NOT NULL DEFAULT 0;
ALTER TABLE artists ADD COLUMN name_canonical NOT NULL DEFAULT '';

CREATE INDEX artists_name_canonical ON artists(name_canonical);

UPDATE artists SET admin=1 WHERE id=8;

CREATE TABLE artist_event (
   artist_id INTEGER REFERENCES artists(id),
   event_id INTEGER REFERENCES events(id),
   role TEXT,
   PRIMARY KEY(artist_id, event_id, role)
);

INSERT INTO artist_event
   SELECT active_artist_id, event_id, role
   FROM user_event ue, users u
   WHERE ue.user_id=u.id
   AND role != 'prompt-voter';

DELETE from user_event WHERE role != 'prompt-voter';

INSERT INTO
   formats (name, created, wc_min, wc_max)
   VALUES ("Polished Story", datetime('now'), 3000, 12000);
