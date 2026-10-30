# File and Document Storage

Load this module for applications that store XML, JSON, documents, images, or
other file payloads on a filesystem, in object storage, in database large
objects, or across a hybrid design.

## Choose the storage boundary

- Keep business facts, ownership, classification, retention, access rules,
  and lifecycle state in the relational model. Store large or independently
  managed payloads outside hot relational rows when that improves lifecycle,
  scanning, access control, delivery, or backup operations.
- Store a stable file identifier and the minimum operational metadata needed
  to locate and govern each payload: owning record, storage provider/key,
  media type, byte length, checksum, created time, scan status, and lifecycle
  state where required. Do not treat a client-supplied filename or path as a
  storage key.
- Use a database foreign key for the owning record and a uniqueness rule for
  the storage identity where appropriate. Avoid storing an unvalidated
  arbitrary filesystem path or URL that callers can use to select a resource.
- Choose XML or JSON in a database column when it is small, transactionally
  coupled, and queried as a document. Normalize fields that need relational
  constraints, joins, or stable cross-document reporting. Use a file/object
  store for large documents or payloads with independent delivery and
  lifecycle.
- Document which system is authoritative, how metadata and payloads stay
  consistent, and how orphaned or missing objects are detected and repaired.
  A database transaction does not make an object-store write atomic; use an
  outbox, staged upload, or reconciliation process when needed.

## Storage options

- **Filesystem:** use only application-managed roots outside the web root.
  Generate storage names, constrain resolved paths to the configured root,
  and do not rely on user-provided paths. Specify shared-volume behavior,
  capacity, backup, restore, malware scanning, and disaster recovery.
- **S3-compatible/object storage:** keep the bucket/container and object key
  separate from user-visible names. Define private-by-default access, scoped
  service identities, encryption, versioning, lifecycle/replication rules,
  integrity checks, and deletion behavior. Use short-lived signed access
  only when required; do not store long-lived credentials or public URLs in
  the model.
- **SQL Server FILESTREAM:** consider it when transactional consistency with
  SQL Server rows and streaming access justify SQL Server-specific storage
  and operational coupling. Verify FILESTREAM enablement, availability-group
  and backup/restore requirements, and ORM/provider support. It is not a
  portable-v1 feature.
- **Oracle:** use SecureFiles LOBs for database-managed large objects when
  transactionality, database security, backup, or retention requirements
  justify keeping payloads in Oracle; evaluate deduplication, compression,
  encryption, and LOB retention for the deployed version.
- **PostgreSQL:** use `bytea` for smaller database-managed values. Large
  Objects provide streaming and separate lifecycle semantics but require
  explicit large-object ownership and cleanup; do not assume row deletion
  removes them. Keep PostGIS geometry as spatial data, not an opaque file.
- **MySQL/MariaDB:** use `BLOB`/`LONGBLOB` only when database transaction and
  backup behavior outweigh row, replication, and storage costs. Large
  payloads otherwise commonly belong in object storage with a relational
  reference.

## Security, metadata, and lifecycle

- Classify payloads and their database references according to what they
  contain, not the storage medium. Apply least privilege, encryption in
  transit and at rest, malware/content scanning, and audited access.
- Do not trust filename extensions or client-provided media types. Validate
  content, enforce size limits, generate safe download names, and prevent
  active content from being served from the application origin.
- Record descriptions, B.C. data classification, and plain-text records
  schedules on the relevant tables and columns. For independently governed
  files, also carry required metadata in the object/file metadata or an
  associated database row; database comments do not automatically govern
  copies in object storage, caches, exports, or backups.
- Define retention and deletion across the relational row, payload versions,
  replicas, temporary upload areas, backups, logs, malware quarantine, and
  derived copies. Do not claim immediate erasure where immutable backups or
  version retention prevent it; document the purge timeline and legal holds.
- Plan for orphan cleanup, failed uploads, retries, checksum verification,
  restore testing, and migration between providers. Preserve identifiers and
  access rules while copying data, and verify counts and checksums before
  cutover and source deletion.

## Model and migration checks

- Include file metadata and lifecycle state in the conceptual and logical
  model even when payload bytes are external.
- Record whether XML/JSON is canonical, schema-validated, versioned, and
  queried by the application. Do not use a document column to hide stable
  relational attributes.
- Test authorized reads and writes, rejected content, size limits,
  consistency recovery, retention jobs, and backup/restore with the chosen
  provider. Use local or disposable storage for tests.
- wwwsqldesigner portable-v1 cannot represent file storage configuration,
  FILESTREAM, LOB storage clauses, or object-store lifecycle policies.
  Represent relationships and metadata in the model, then document physical
  storage and lifecycle details in migrations and the design record.
