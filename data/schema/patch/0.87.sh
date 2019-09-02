#!/bin/bash

cd "$( dirname "$0" )/../../.."

# sqlite3 data/WriteOff.db <<SQL
# ALTER TABLE genres ADD COLUMN banner_id TEXT;
# ALTER TABLE genres ADD COLUMN color TEXT;
# ALTER TABLE genres ADD COLUMN completion INTEGER;
# ALTER TABLE genres ADD COLUMN established BIT NOT NULL DEFAULT 0;
# ALTER TABLE genres ADD COLUMN promoted BIT NOT NULL DEFAULT 0;
# ALTER TABLE genres ADD COLUMN owner_id INTEGER NOT NULL DEFAULT 8 REFERENCES artists(id);
# UPDATE genres SET promoted=1, established=1, color="#3d2f00";
# CREATE INDEX genre_owner_id ON genres (owner_id);

# CREATE TABLE artist_genre (
#    artist_id INTEGER REFERENCES artists(id),
#    genre_id INTEGER REFERENCES genres(id),
#    role TEXT,
#    created TIMESTAMP,
#    PRIMARY KEY (artist_id, genre_id)
# );
# CREATE INDEX artist_genre_artist_id ON artist_genre (artist_id);
# CREATE INDEX artist_genre_genre_id ON artist_genre (genre_id);
# SQL

# Old: (1, Short story), (2, Minific), (3, Polished short story)
# New: (1, Flashfic), (2, Minific), (3, Vignette), (4, Short story)
sqlite3 data/WriteOff.db <<SQL
DROP TABLE formats;
UPDATE events SET format_id=4 WHERE format_id != 2;
UPDATE schedules SET format_id=4 WHERE format_id != 2;
UPDATE OR REPLACE sub_formats SET format_id=4 WHERE format_id != 2;
SQL
