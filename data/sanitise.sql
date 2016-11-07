-- Removes confidential data from the database
-- such that it is suitable to give out publicly

UPDATE users SET
	-- "hunter2"
	active_artist_id = NULL,
	password = '$2$10$6F2eyWuzX1DmtnRsrDkU0uOa7PeedmRNO9TlVCCADtF9RIZD0ecwu',
	email = NULL;

DELETE FROM tokens;
DELETE FROM sub_formats;
DELETE FROM sub_genres;
DELETE FROM sub_triggers;

UPDATE entrys SET user_id = NULL;
UPDATE prompts SET user_id = NULL;
UPDATE ballots SET user_id = NULL;
UPDATE artists SET user_id = NULL;
