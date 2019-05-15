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

ALTER TABLE events ADD COLUMN tallied BIT NOT NULL DEFAULT 0;

UPDATE
   events
SET
   tallied = 1
WHERE
   (SELECT COUNT(*) FROM scores WHERE event_id = events.id) != 0;

COMMIT;
