-- DESCRIPTION
--
-- Schema patch for WriteOff.pm's database from 0.36 to 0.37
--
-- AUTHOR
--
-- Cameron Thornton <cthor@cpan.org>

BEGIN TRANSACTION;
   ALTER TABLE tokens RENAME TO tokens_tmp;

   CREATE TABLE tokens (
      user_id   INTEGER REFERENCES users(id) ON DELETE CASCADE NOT NULL,
      "type"    TEXT NOT NULL,
      value     TEXT NOT NULL,
      address   TEXT,
      expires   TIMESTAMP NOT NULL,
      PRIMARY KEY (user_id, "type")
   );

   INSERT INTO
      tokens
   SELECT
      *
   FROM
      tokens_tmp;

   DROP TABLE tokens_tmp;
COMMIT;
