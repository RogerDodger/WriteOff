ALTER TABLE posts ADD COLUMN role TEXT NOT NULL DEFAULT 'user';
UPDATE posts SET role='admin' WHERE artist_id=8;
