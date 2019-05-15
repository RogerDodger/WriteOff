CREATE TABLE formats (
   id INTEGER PRIMARY KEY,
   name TEXT,
   created TIMESTAMP
);

CREATE TABLE genres (
   id INTEGER PRIMARY KEY,
   name TEXT,
   descr TEXT,
   created TIMESTAMP
);

INSERT INTO formats VALUES
   (1, "Short Story", datetime()),
   (2, "Minific", datetime());

INSERT INTO genres VALUES
   (1, "Novel", "Fiction of no particular genre", datetime()),
   (2, "FiM", "Fiction based on Friendship is Magic", datetime());

ALTER TABLE events ADD COLUMN format_id INTEGER REFERENCES formats(id) ON DELETE CASCADE;
ALTER TABLE events ADD COLUMN genre_id INTEGER REFERENCES genres(id) ON DELETE CASCADE;

UPDATE events SET genre_id=2;
UPDATE events SET format_id=1;
UPDATE events SET format_id=2 WHERE wc_max <= 1000;

CREATE VIEW scoreboards AS
SELECT
   artists.id AS id,
   artists.name AS name,
   SUM(scores.value) AS score,
   genre_id AS genre_id,
   format_id AS format_id
FROM
   artists
CROSS JOIN
   scores ON artists.id=scores.artist_id
CROSS JOIN
   events ON scores.event_id=events.id
GROUP BY
   artists.id, genre_id, format_id

UNION

SELECT
   artists.id AS id,
   artists.name AS name,
   SUM(scores.value) AS score,
   genre_id AS genre_id,
   NULL AS format_id
FROM
   artists
CROSS JOIN
   scores ON artists.id=scores.artist_id
CROSS JOIN
   events ON scores.event_id=events.id
GROUP BY
   artists.id, genre_id

UNION

SELECT
   artists.id AS id,
   artists.name AS name,
   SUM(scores.value) AS score,
   NULL AS genre_id,
   NULL AS format_id
FROM
   artists
CROSS JOIN
   scores ON artists.id=scores.artist_id
GROUP BY
   artists.id

ORDER BY score DESC;
