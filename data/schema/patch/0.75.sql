UPDATE schedules SET next = datetime(next, '-4 days') WHERE format_id = 1;
UPDATE format_rounds SET offset = offset + 4 WHERE format_id = 1;
INSERT INTO format_rounds VALUES (null, 1, 'drawing', 'art', 'submit', 0, 4);
INSERT INTO format_rounds VALUES (null, 1, 'final', 'art', 'vote', 4, 5);
