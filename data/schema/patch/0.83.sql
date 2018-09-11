CREATE TABLE polls (
	id integer primary key,
	user_id integer references users(id) not null,
	title text not null,
	voters integer not null default 0,
	finished bit not null default 0,
	tallied bit not null default 0,
	created timestamp,
	updated timestamp
);

CREATE TABLE bids (
	id integer primary key,
	poll_id integer references polls(id),
	name text not null,
	rating real,
	error real
);

BEGIN TRANSACTION;
	ALTER TABLE ballots RENAME TO ballots_tmp;

	CREATE TABLE ballots (
		id integer primary key,
		event_id integer references events(id),
		round_id integer references rounds(id),
		poll_id integer references polls(id),
		user_id integer references users(id),
		deviance real,
		absolute bit default 0 not null,
		created timestamp,
		updated timestamp
	);

	INSERT INTO ballots
	SELECT id, event_id, round_id, null, user_id, deviance, absolute, created, updated
	FROM ballots_tmp;

	DROP TABLE ballots_tmp;
COMMIT;

CREATE TABLE bid_votes (
	id integer primary key,
	ballot_id integer references ballots(id),
	bid_id integer references bids(id),
	value integer,
	abstained bit not null default 0
);
