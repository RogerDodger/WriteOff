#!/bin/bash

cd "$( dirname "$0" )/../../.."

sqlite3 data/WriteOff.db <<SQL
ALTER TABLE genres ADD COLUMN banner_id TEXT;
ALTER TABLE genres ADD COLUMN color TEXT;
ALTER TABLE genres ADD COLUMN completion INTEGER;
ALTER TABLE genres ADD COLUMN established BIT NOT NULL DEFAULT 0;
ALTER TABLE genres ADD COLUMN promoted BIT NOT NULL DEFAULT 0;
ALTER TABLE genres ADD COLUMN owner_id INTEGER NOT NULL DEFAULT 8 REFERENCES artists(id);
UPDATE genres SET promoted=1, established=1, color="#3d2f00";
CREATE INDEX genre_owner_id ON genres (owner_id);

CREATE TABLE artist_genre (
   artist_id INTEGER REFERENCES artists(id),
   genre_id INTEGER REFERENCES genres(id),
   role TEXT,
   created TIMESTAMP,
   PRIMARY KEY (artist_id, genre_id)
);
CREATE INDEX artist_genre_artist_id ON artist_genre (artist_id);
CREATE INDEX artist_genre_genre_id ON artist_genre (genre_id);

DROP TABLE formats;

-- Old: (1, Short story), (2, Minific), (3, Polished short story)
-- New: (1, Flashfic), (2, Minific), (3, Vignette), (4, Short story)
UPDATE events SET format_id=4 WHERE format_id != 2;
UPDATE OR REPLACE sub_formats SET format_id=4 WHERE format_id != 2;

ALTER TABLE schedules RENAME TO schedules_old;

CREATE TABLE schedules (
   id        INTEGER PRIMARY KEY,
   genre_id  INTEGER REFERENCES genres(id) NOT NULL,
   wc_min    INTEGER NOT NULL,
   wc_max    INTEGER NOT NULL,
   next      TIMESTAMP NOT NULL,
   period    INTEGER NOT NULL
);
CREATE INDEX schedules_genre_id ON schedules (genre_id);

INSERT INTO schedules
SELECT
   id, genre_id,
   CASE WHEN format_id=2 THEN 400 ELSE 2000 END,
   CASE WHEN format_id=2 THEN 750 ELSE 8000 END,
   next, period
FROM schedules_old;

DROP TABLE schedules_old;

--- Testing
UPDATE genres SET owner_id=256 WHERE id=3;
UPDATE genres SET banner_id='8d-1-4299f545' WHERE id=1;
UPDATE genres SET banner_id='a3-2-d2d7c302' WHERE id=2;
UPDATE genres SET banner_id='1e-3-9f17989a' WHERE id=3;
SQL
