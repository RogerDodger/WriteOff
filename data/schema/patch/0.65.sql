BEGIN TRANSACTION;
   DROP INDEX replys_idx_parent_id;
   DROP INDEX replys_idx_child_id;
   ALTER TABLE replys RENAME TO replys_tmp;

   CREATE TABLE replys (
     parent_id INTEGER NOT NULL,
     child_id INTEGER NOT NULL,
     PRIMARY KEY (parent_id, child_id),
     FOREIGN KEY (parent_id) REFERENCES posts(id),
     FOREIGN KEY (child_id) REFERENCES posts(id)
   );
   CREATE INDEX replys_idx_parent_id ON replys (parent_id);
   CREATE INDEX replys_idx_child_id ON replys (child_id);

   INSERT INTO replys SELECT * FROM replys_tmp;
   DROP TABLE replys_tmp;
COMMIT;
