ALTER TABLE storys ADD COLUMN prelim_score INTEGER;
ALTER TABLE storys ADD COLUMN prelim_stdev REAL;
ALTER TABLE storys ADD COLUMN controversial REAL;

UPDATE storys SET controversial=public_stdev;
