CREATE TABLE replies (
  parent_id INTEGER,
  child_id INTEGER,
  PRIMARY KEY (parent_id, child_id),
  FOREIGN KEY (parent_id) REFERENCES posts(id),
  FOREIGN KEY (child_id) REFERENCES posts(id)
);
CREATE INDEX replies_idx_parent_id ON replies (parent_id);
CREATE INDEX replies_idx_child_id ON replies (child_id);
