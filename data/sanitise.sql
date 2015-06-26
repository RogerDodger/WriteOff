-- Removes confidential data from the database
-- such that it is suitable to give out publicly

UPDATE users SET
	-- "hunter2"
	password = '$2$10$6F2eyWuzX1DmtnRsrDkU0uOa7PeedmRNO9TlVCCADtF9RIZD0ecwu',
	email = NULL,
	timezone = 'UTC',
	ip = NULL;

DELETE FROM tokens;
DELETE FROM bans;

UPDATE storys SET ip = NULL, user_id = NULL;
UPDATE images SET ip = NULL, user_id = NULL;
UPDATE prompts SET ip = NULL, user_id = NULL;
UPDATE vote_records SET ip = NULL, user_id = NULL;
UPDATE artists SET user_id = NULL;
