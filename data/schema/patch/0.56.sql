DROP VIEW scoreboards;
CREATE VIEW scores AS
SELECT
  artists.id AS id,
  artists.name AS name,
  SUM(entrys.score_genre) AS score,
  events.genre_id AS genre_id,
  NULL AS format_id
FROM
  artists
CROSS JOIN
  entrys ON artists.id=entrys.artist_id
CROSS JOIN
  events ON entrys.event_id=events.id AND events.tallied=1
WHERE
  disqualified=0 AND artist_public=1
GROUP BY
  artists.id, genre_id

UNION

SELECT
  artists.id AS id,
  artists.name AS name,
  SUM(entrys.score_format) AS score,
  events.genre_id AS genre_id,
  events.format_id AS format_id
FROM
  artists
CROSS JOIN
  entrys ON artists.id=entrys.artist_id
CROSS JOIN
  events ON entrys.event_id=events.id AND events.tallied=1
WHERE
  disqualified=0 AND artist_public=1
GROUP BY
  artists.id, genre_id, format_id

ORDER BY score DESC;

CREATE TABLE scoreboards (
  genre_id integer NOT NULL,
  format_id integer,
  lang text NOT NULL,
  body text NOT NULL,
  FOREIGN KEY (format_id) REFERENCES formats(id),
  FOREIGN KEY (genre_id) REFERENCES genres(id)
);
CREATE INDEX scoreboards_idx_format_id ON scoreboards (format_id);
CREATE INDEX scoreboards_idx_genre_id ON scoreboards (genre_id);
