ALTER TABLE posts ADD COLUMN children_render TEXT;

ALTER TABLE events ADD COLUMN last_post_id INTEGER REFERENCES posts(id);
UPDATE events SET last_post_id =
	(SELECT id FROM posts WHERE event_id=events.id ORDER BY created DESC LIMIT 1);
