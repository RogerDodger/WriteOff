create table notifs (
	id integer primary key,
	notif_id integer not null,
	user_id integer references users(id) not null,
	post_id integer references posts(id),
	read bit default 0 not null,
	created timestamp
);

create index notif_idx_user_id on notifs (user_id);
create index notif_idx_user_id_read on notifs (user_id, read);
