-- Someone created an artist called "Anonymous" in event 50
-- I'm not sure if I should stop people from doing that, but in this case it was accidental, so fixing the
UPDATE guesses SET artist_id=25 WHERE artist_id=779;
UPDATE theorys SET accuracy=2 WHERE id=2938;
UPDATE theorys SET accuracy=7 WHERE id=2951;
UPDATE entrys SET artist_id=25 WHERE artist_id=779;
UPDATE entrys SET score = 83.8793321662524 - 63.8420632675959 * 2 WHERE id = 1817;
UPDATE entrys SET score_format = score * 0.9 * 0.9 * 0.9,
                  score_genre  = score * 0.9 * 0.9 * 0.9 * 0.9 * 0.9 * 0.9 WHERE id = 1817;
DELETE FROM awards WHERE entry_id=1817;
