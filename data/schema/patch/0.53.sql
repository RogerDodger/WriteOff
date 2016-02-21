DROP VIEW scoreboards;
CREATE VIEW scoreboards AS
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
GROUP BY
	artists.id, genre_id, format_id

ORDER BY score DESC;

UPDATE artists SET user_id = (
	SELECT entrys.user_id
	FROM entrys
	WHERE entrys.artist_id=artists.id
	GROUP BY user_id
	ORDER BY COUNT(*) DESC
	LIMIT 1)
WHERE user_id IS NULL;

-- Anonymous
UPDATE artists SET user_id=NULL WHERE id=25;
