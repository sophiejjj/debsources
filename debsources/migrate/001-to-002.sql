--- step 1: create and populate table "files"

-- create new file table, without constraints for now
CREATE TABLE files (
  id SERIAL NOT NULL, 
  version_id INTEGER NOT NULL, 
  path BYTEA NOT NULL, 
  PRIMARY KEY (id)
  -- UNIQUE (version_id, path), 
  -- FOREIGN KEY(version_id) REFERENCES versions (id)
  --   ON DELETE CASCADE
);

--- fill it in using data from checksums
INSERT INTO files (version_id, path)
  SELECT version_id, path FROM checksums;

--- set desired constraints and index the table
ALTER TABLE files
  ADD CONSTRAINT files_version_id_path_key
    UNIQUE(version_id, path),
  ADD CONSTRAINT files_version_id_fkey
    FOREIGN KEY (version_id) REFERENCES versions(id)
    ON DELETE CASCADE;

CREATE INDEX ix_files_path ON files (path);


--- step 2: patch table "checksums"

--- add file_id foreign key to checksums (invalid)
ALTER TABLE checksums
  ADD COLUMN file_id INTEGER,
  ADD CONSTRAINT checksums_file_id_fkey
    FOREIGN KEY (file_id) REFERENCES files(id)
    ON DELETE CASCADE NOT VALID;

--- fill file_id fetching data from files.id
UPDATE checksums
  SET   file_id = files.id
  FROM  files
  WHERE checksums.version_id = files.version_id
  AND   checksums.path = files.path;

--- validate file_id and drop column path
ALTER TABLE checksums
  VALIDATE CONSTRAINT checksums_file_id_fkey,
  ALTER COLUMN file_id SET NOT NULL,
  DROP COLUMN path;

--- reorder columns so that sha256 comes last.  Unfortunately, Postgres doesn't
--- offer a nicer way to do this; see
--- https://wiki.postgresql.org/wiki/Alter_column_position#Add_columns_and_move_data
ALTER TABLE checksums ADD COLUMN sha256_new VARCHAR(64);
UPDATE checksums SET sha256_new = sha256;
ALTER TABLE checksums DROP COLUMN sha256;
ALTER TABLE checksums RENAME COLUMN sha256_new TO sha256;
ALTER TABLE checksums ALTER COLUMN sha256 SET NOT NULL;

--- (re-)add indexes and constraints to checksums
ALTER TABLE checksums
  ADD CONSTRAINT checksums_version_id_file_id_key
    UNIQUE (version_id, file_id);
CREATE INDEX ix_checksums_sha256 ON checksums (sha256);


--- step 3: patch table "ctags"

--- add file_id foreign key to ctags (invalid)
ALTER TABLE ctags
  ADD COLUMN file_id INTEGER,
  ADD CONSTRAINT ctags_file_id_fkey
    FOREIGN KEY (file_id) REFERENCES files(id)
    ON DELETE CASCADE NOT VALID;

--- fill file_id fetching data from files.id
UPDATE ctags
  SET   file_id = files.id
  FROM  files
  WHERE ctags.version_id = files.version_id
  AND   ctags.path = files.path;

--- validate file_id and drop column path
ALTER TABLE ctags
  VALIDATE CONSTRAINT ctags_file_id_fkey,
  ALTER COLUMN file_id SET NOT NULL,
  DROP COLUMN path;

--- reorder columns so that line, kind, languages comes last
ALTER TABLE ctags
  ADD COLUMN line_new INTEGER,
  ADD COLUMN kind_new VARCHAR,
  ADD COLUMN language_new ctags_languages;
UPDATE ctags
  SET (line_new, kind_new, language_new) = (line, kind, language);
ALTER TABLE ctags
  DROP COLUMN line,
  DROP COLUMN kind,
  DROP COLUMN language;
ALTER TABLE ctags RENAME COLUMN line_new TO line;
ALTER TABLE ctags RENAME COLUMN kind_new TO kind;
ALTER TABLE ctags RENAME COLUMN language_new TO language;
ALTER TABLE ctags ALTER COLUMN line SET NOT NULL;


--- step 4: add missing foreign key indexes

CREATE INDEX ix_versions_package_id ON versions (package_id);
CREATE INDEX ix_suitesmapping_sourceversion_id ON suitesmapping (sourceversion_id);
CREATE INDEX ix_files_version_id ON files (version_id);
CREATE INDEX ix_checksums_version_id ON checksums (version_id);
CREATE INDEX ix_checksums_file_id ON checksums (file_id);
CREATE INDEX ix_binaryversions_binarypackage_id ON binaryversions (binarypackage_id);
CREATE INDEX ix_binaryversions_sourceversion_id ON binaryversions (sourceversion_id);
CREATE INDEX ix_sloccounts_sourceversion_id ON sloccounts (sourceversion_id);
CREATE INDEX ix_metrics_sourceversion_id ON metrics (sourceversion_id);
