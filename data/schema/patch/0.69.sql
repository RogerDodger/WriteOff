CREATE TABLE email_triggers (
   id INTEGER PRIMARY KEY,
   name TEXT,
   template TEXT,
   prompt_in_subject BIT
);

INSERT INTO email_triggers VALUES
   (null, 'eventCreated', 'email/event-created.tt', 0),
   (null, 'promptSelected', 'email/prompt-selected.tt', 0),
   (null, 'votingStarted', 'email/voting-started.tt', 1),
   (null, 'resultsUp', 'email/results-up.tt', 1);

CREATE TABLE sub_triggers (
   user_id INTEGER,
   trigger_id INTEGER,
   PRIMARY KEY (user_id, trigger_id),
   FOREIGN KEY (user_id) REFERENCES users(id),
   FOREIGN KEY (trigger_id) REFERENCES email_triggers(id)
);

CREATE TABLE sub_genres (
   user_id INTEGER,
   genre_id INTEGER,
   PRIMARY KEY (user_id, genre_id),
   FOREIGN KEY (user_id) REFERENCES users(id),
   FOREIGN KEY (genre_id) REFERENCES genres(id)
);

CREATE TABLE sub_formats (
   user_id INTEGER,
   format_id INTEGER,
   PRIMARY KEY (user_id, format_id),
   FOREIGN KEY (user_id) REFERENCES users(id),
   FOREIGN KEY (format_id) REFERENCES formats(id)
);

CREATE INDEX sub_triggers_idx_user_id ON sub_triggers (user_id);
CREATE INDEX sub_triggers_idx_trigger_id ON sub_triggers (trigger_id);

CREATE INDEX sub_genres_idx_user_id ON sub_genres (user_id);
CREATE INDEX sub_genres_idx_genre_id ON sub_genres (genre_id);

CREATE INDEX sub_formats_idx_user_id ON sub_formats (user_id);
CREATE INDEX sub_formats_idx_format_id ON sub_formats (format_id);

INSERT INTO sub_triggers
SELECT id, 1 FROM users WHERE mailme=1;

INSERT INTO sub_genres
SELECT id, 1 FROM users WHERE mailme=1;
INSERT INTO sub_genres
SELECT id, 2 FROM users WHERE mailme=1;

INSERT INTO sub_formats
SELECT id, 1 FROM users WHERE mailme=1;
INSERT INTO sub_formats
SELECT id, 2 FROM users WHERE mailme=1;
