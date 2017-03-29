ALTER TABLE rounds ADD COLUMN tallied BIT;
UPDATE rounds SET tallied=1 WHERE action='vote' AND event_id<66;
