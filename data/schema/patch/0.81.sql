CREATE TABLE schedule_rounds (
   id INTEGER PRIMARY KEY,
   schedule_id INTEGER,
   name TEXT,
   mode TEXT,
   action TEXT,
   offset INTEGER,
   duration INTEGER,
   FOREIGN KEY (schedule_id) REFERENCES schedules(id)
);

INSERT INTO schedule_rounds
SELECT null, s.id, fr.name, fr.mode, fr.action, fr.offset, fr.duration
FROM format_rounds fr, schedules s
WHERE fr.format_id = s.format_id;

DROP TABLE format_rounds;
