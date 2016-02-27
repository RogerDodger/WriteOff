CREATE TABLE scoreboards (
  id INTEGER PRIMARY KEY NOT NULL,
  genre_id integer NOT NULL,
  format_id integer,
  lang text NOT NULL,
  body text NOT NULL,
  FOREIGN KEY (format_id) REFERENCES formats(id),
  FOREIGN KEY (genre_id) REFERENCES genres(id)
);
CREATE INDEX scoreboards_idx_format_id ON scoreboards (format_id);
CREATE INDEX scoreboards_idx_genre_id ON scoreboards (genre_id);
