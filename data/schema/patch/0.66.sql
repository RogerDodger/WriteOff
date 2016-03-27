DROP TABLE IF EXISTS post_votes;
DROP TABLE IF EXISTS scoreboards;

ALTER TABLE posts ADD COLUMN score INTEGER NOT NULL DEFAULT 0;

CREATE TABLE post_votes (
	user_id INTEGER,
	post_id INTEGER,
	value INTEGER,
	PRIMARY KEY (user_id, post_id),
	FOREIGN KEY (user_id) REFERENCES users(id),
	FOREIGN KEY (post_id) REFERENCES posts(id)
);
CREATE INDEX post_votes_idx_post_id ON post_votes (post_id);
CREATE INDEX post_votes_idx_user_id ON post_votes (user_id);
