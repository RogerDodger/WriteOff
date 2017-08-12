UPDATE schedules SET next = datetime(next, '+4 days') WHERE format_id = 1;
UPDATE format_rounds SET offset = offset - 4 WHERE format_id = 1 AND mode != 'art';
