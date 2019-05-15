ALTER TABLE votes ADD COLUMN percentile REAL;

ALTER TABLE vote_records ADD COLUMN story_id INTEGER
REFERENCES storys(id) ON DELETE CASCADE ON UPDATE CASCADE;

UPDATE votes SET percentile =
   100 * (
      value -
      (SELECT MIN(value) FROM votes v WHERE votes.record_id=v.record_id)
   ) /
   (
      (SELECT MAX(value) FROM votes v WHERE votes.record_id=v.record_id) -
      (SELECT MIN(value) FROM votes v WHERE votes.record_id=v.record_id)
   ) WHERE (SELECT event_id FROM vote_records WHERE id=record_id)>32;

UPDATE storys SET controversial =
   (SELECT STDEV(percentile) FROM votes WHERE story_id=storys.id)
WHERE event_id=33;
