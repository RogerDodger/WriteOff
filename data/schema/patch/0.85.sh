#!/bin/bash

sqlite3 data/WriteOff.db <<SQL
UPDATE rounds          SET mode='pic' WHERE mode='art';
UPDATE schedule_rounds SET mode='pic' WHERE mode='art';
UPDATE theorys         SET mode='pic' WHERE mode='art';
SQL

if [ -d root/static/art ]; then
	mv root/static/pic/.gitignore root/static/art
	mv root/static/pic/thumb/.gitignore root/static/art/thumb
	rm -r root/static/pic
	mv root/static/art root/static/pic
fi;
