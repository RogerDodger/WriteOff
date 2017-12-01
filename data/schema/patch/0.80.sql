UPDATE rounds SET
	start = datetime(start, '+4 days'),
	end = datetime(end, '+4 days')
WHERE event_id = 78 AND mode = 'art' AND action = 'vote';

UPDATE rounds SET
	start = datetime(start, '+3 days'),
	end = datetime(end, '+4 days')
WHERE event_id = 78 AND mode = 'art' AND action = 'submit';
