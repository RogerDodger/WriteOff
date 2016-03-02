DELETE FROM guesses WHERE (SELECT disqualified FROM entrys WHERE id=guesses.entry_id);

UPDATE theorys SET
	accuracy=(
		SELECT COUNT(*)
		FROM guesses g
		LEFT JOIN entrys e ON e.id=g.entry_id
		WHERE g.theory_id=theorys.id
		AND e.artist_id=g.artist_id)
	WHERE event_id != 47;

UPDATE theorys SET
	artist_id=(
		SELECT active_artist_id
		FROM users
		WHERE users.id=theorys.user_id)
	WHERE artist_id IS NULL;

