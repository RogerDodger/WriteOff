ALTER TABLE formats ADD COLUMN wc_min INTEGER;
ALTER TABLE formats ADD COLUMN wc_max INTEGER;

CREATE TABLE format_rounds (
   id INTEGER PRIMARY KEY,
   format_id INTEGER,
   name TEXT,
   mode TEXT,
   action TEXT,
   offset INTEGER,
   duration INTEGER,
   FOREIGN KEY (format_id) REFERENCES formats(id)
);

-- format 1 = short story, 2 = minific
-- genre 1 = original, 2 = fim

UPDATE formats SET wc_min=2000, wc_max=8000 WHERE id=1;
UPDATE formats SET wc_min=400, wc_max=750 WHERE id=2;

INSERT INTO format_rounds VALUES
   (null, 1, "writing", "fic", "submit", 0, 3),
   (null, 1, "prelim", "fic", "vote", 3, 6),
   (null, 1, "final", "fic", "vote", 9, 4),
   (null, 2, "writing", "fic", "submit", 0, 1),
   (null, 2, "prelim", "fic", "vote", 1, 6),
   (null, 2, "final", "fic", "vote", 7, 4);

ALTER TABLE schedules RENAME TO jobs;

CREATE TABLE schedules (
   id INTEGER PRIMARY KEY,
   format_id INTEGER,
   genre_id INTEGER,
   next TIMESTAMP,
   period INTEGER,
   FOREIGN KEY (format_id) REFERENCES formats(id),
   FOREIGN KEY (genre_id) REFERENCES genres(id)
);

INSERT INTO schedules VALUES
   (null, 1, 2, '2016-04-22 12:00:00', 12),
   (null, 2, 1, '2016-05-13 12:00:00', 12),
   (null, 2, 2, '2016-06-03 12:00:00', 12),
   (null, 1, 1, '2016-06-24 12:00:00', 12);
