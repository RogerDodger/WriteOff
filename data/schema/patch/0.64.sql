DROP TABLE replies;

CREATE TABLE replys (
  parent_id INTEGER,
  child_id INTEGER,
  PRIMARY KEY (parent_id, child_id),
  FOREIGN KEY (parent_id) REFERENCES posts(id),
  FOREIGN KEY (child_id) REFERENCES posts(id)
);
CREATE INDEX replys_idx_parent_id ON replys (parent_id);
CREATE INDEX replys_idx_child_id ON replys (child_id);
