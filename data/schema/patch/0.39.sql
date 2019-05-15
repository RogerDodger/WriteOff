-- DESCRIPTION
--
-- Schema patch for WriteOff.pm's database from 0.38 to 0.39
--
-- DEPENDENCIES
--
-- `extension-functions.c` must be loaded for the STDEV function
--
-- AUTHOR
--
-- Cameron Thornton <cthor@cpan.org>

BEGIN TRANSACTION;

-- Voterecords
ALTER TABLE vote_records ADD COLUMN filled BIT NOT NULL DEFAULT 0;
ALTER TABLE vote_records ADD COLUMN mean  REAL;
ALTER TABLE vote_records ADD COLUMN stdev REAL;

UPDATE
   vote_records
SET
   filled
      = (SELECT COUNT(*) FROM votes
         WHERE record_id = vote_records.id
         AND value IS NOT NULL) != 0,
   mean
      = (SELECT AVG(value) FROM votes WHERE record_id = vote_records.id),
   stdev
      = (SELECT STDEV(value) FROM votes WHERE record_id = vote_records.id);

-- Images
ALTER TABLE images ADD COLUMN public_score REAL;
ALTER TABLE images ADD COLUMN public_stdev REAL;
ALTER TABLE images ADD COLUMN rank         INTEGER;
ALTER TABLE images ADD COLUMN rank_low     INTEGER;

UPDATE
   images
SET
   public_score
      = (SELECT COUNT(*) FROM image_story WHERE image_id = images.id)
      + IFNULL(
         (SELECT AVG(votes.value) FROM votes WHERE image_id = images.id),
         0
      ),
   public_stdev
      = CASE WHEN (SELECT COUNT(*) FROM votes WHERE image_id = images.id) != 0
         THEN (SELECT STDEV(votes.value) FROM votes WHERE image_id = images.id)
         ELSE NULL END;

UPDATE
   images
SET
   rank
      = (SELECT COUNT(*) FROM images inn
         WHERE inn.event_id = images.event_id
         AND IFNULL(inn.public_score, -1)
            > IFNULL(images.public_score, -1)),
   rank_low
      = -1 + (SELECT COUNT(*) FROM images inn
         WHERE inn.event_id = images.event_id
         AND IFNULL(inn.public_score, -1)
            >= IFNULL(images.public_score, -1));

-- Storys
ALTER TABLE storys RENAME TO storys_tmp;

CREATE TABLE storys (
   id             INTEGER PRIMARY KEY,
   event_id       INTEGER REFERENCES events(id) ON DELETE CASCADE NOT NULL,
   user_id        INTEGER REFERENCES users(id) ON DELETE CASCADE,
   ip             TEXT,
   title          TEXT COLLATE NOCASE NOT NULL,
   author         TEXT DEFAULT 'Anonymous' COLLATE NOCASE NOT NULL,
   website        TEXT,
   contents       TEXT NOT NULL,
   wordcount      INTEGER NOT NULL,
   seed           REAL,
   views          INTEGER DEFAULT 0,
   finalist       BIT DEFAULT 0 NOT NULL,
   candidate      BIT DEFAULT 0 NOT NULL,
   private_score  INTEGER,
   public_score   REAL,
   public_stdev   REAL,
   rank           INTEGER,
   rank_low       INTEGER,
   created        TIMESTAMP,
   updated        TIMESTAMP
);

INSERT INTO
   storys (id, event_id, user_id, ip, title, author, website, contents,
      wordcount, seed, views, finalist, candidate, created, updated)
SELECT
   id, event_id, user_id, ip, title, author, website, contents, wordcount,
      seed, views, is_finalist, is_public_candidate, created, updated
FROM
   storys_tmp;

DROP TABLE storys_tmp;

UPDATE
   storys
SET
   candidate
      = (SELECT COUNT(*) FROM votes v, vote_records r
         WHERE v.record_id = r.id
         AND r.round = 'public'
         AND v.story_id = storys.id) != 0,
   finalist
      = (SELECT COUNT(*) FROM votes v, vote_records r
         WHERE v.record_id = r.id
         AND r.round = 'private'
         AND v.story_id = storys.id) != 0,
   public_score
      = (SELECT AVG(v.value) FROM votes v, vote_records r
         WHERE v.record_id = r.id
         AND r.round = 'public'
         AND v.story_id = storys.id),
   public_stdev
      = (SELECT STDEV(v.value) FROM votes v, vote_records r
         WHERE v.record_id = r.id
         AND r.round = 'public'
         AND v.story_id = storys.id),
   private_score
      = (SELECT SUM(v.value) FROM votes v, vote_records r
         WHERE v.record_id = r.id
         AND r.round = 'private'
         AND v.story_id = storys.id);

UPDATE
   storys
SET
   rank
      = (SELECT COUNT(*) FROM storys inn
         WHERE inn.event_id = storys.event_id
         AND (
            IFNULL(inn.private_score, -99)
               > IFNULL(storys.private_score, -99)
            OR IFNULL(inn.private_score, -99)
               = IFNULL(storys.private_score, -99)
                  AND IFNULL(inn.public_score, -1)
                     > IFNULL(storys.public_score, -1)
         )),
   rank_low
      = -1 + (SELECT COUNT(*) FROM storys inn
         WHERE inn.event_id = storys.event_id
         AND (
            IFNULL(inn.private_score, -99)
               > IFNULL(storys.private_score, -99)
            OR IFNULL(inn.private_score, -99)
               = IFNULL(storys.private_score, -99)
                  AND IFNULL(inn.public_score, -1)
                     >= IFNULL(storys.public_score, -1)
         ));
COMMIT;
