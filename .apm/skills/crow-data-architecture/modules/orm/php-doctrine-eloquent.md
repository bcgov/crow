# PHP: Doctrine and Eloquent

Confirm the framework (Symfony, Laravel, or another), the ORM and DBAL
versions, and the database driver first.

## Metadata

- Doctrine ORM: set comments through mapping options, for example
  `#[ORM\Table(options: ['comment' => '…'])]` and
  `#[ORM\Column(options: ['comment' => '…'])]`. DBAL emits the platform's
  comment mechanism; check the generated migration SQL.
- Doctrine DBAL 3 can append a type hint such as `(DC2Type:json)` to column
  comments. Parsers must locate the last `@bcgov{...}` block rather than
  assume it ends the comment; DBAL 4 no longer writes these hints.
- Laravel migrations: `$table->comment('…')` for tables and
  `->comment('…')` for columns. Support depends on the driver; Oracle
  requires a third-party driver. Check the SQL with
  `php artisan migrate --pretend`.
- Add structured metadata (SQL Server extended properties, Oracle
  annotations) with raw SQL in the same migration: `$this->addSql(...)` in
  Doctrine Migrations or `DB::statement(...)` in Laravel. Guard
  platform-specific SQL when a project supports several engines.

## Mapping

- Doctrine: map money with `decimal` and the PHP string type or a money
  value object, never `float`. Use `datetimetz_immutable` or a UTC
  convention with `datetime_immutable`. Use embeddables for value objects
  and `#[ORM\Version]` for optimistic locking. Catch and handle
  `OptimisticLockException` as a conflict rather than silently retrying.
- Doctrine associations: set `onDelete` at the database level deliberately
  and avoid ORM `cascade: ['remove']` on large collections.
- Eloquent: declare casts such as `'amount' => 'decimal:2'` and
  `'submitted_at' => 'immutable_datetime'`, and define foreign keys with
  `foreignId(...)->constrained()` and explicit `cascadeOnDelete()` or
  `restrictOnDelete()`.
- Eloquent has no built-in optimistic version column. Where stale writes
  matter, add a version counter and update atomically with both the primary
  key and expected version in the predicate; verify the affected-row count
  and increment the version. Use `lockForUpdate()` only inside a short
  transaction for operations that require pessimistic serialization.
- Laravel's `SoftDeletes` adds `deleted_at`. Account for it in unique
  indexes, foreign keys, reporting, and records disposition.
- Use explicit table and column names when the database convention differs
  from framework defaults.

## Migrations

- Doctrine: generate with `doctrine:migrations:diff`, then edit for safe
  ordering, batching, and metadata. Run `doctrine:schema:validate` in CI to
  detect mapping drift.
- Treat Doctrine's `doctrine_migration_versions` or Laravel's `migrations`
  table as the applied-migration ledger. Do not duplicate it with a second
  schema-version table unless the application needs a separate compatibility
  contract.
- Laravel: modifying a column with `->change()` must restate every attribute
  to keep, including comments, nullability, and defaults; otherwise they
  are dropped.
- Provide `down()` methods where reversal is safe, and document
  irreversible steps.
- Run migrations from the deployment pipeline, not on web requests.

## Testing

- Test against the real engine; SQLite in tests hides type, constraint, and
  locking differences.
- Assert catalogue metadata after applying migrations.
- Detect N+1 queries (eager loading with `with()` in Eloquent, fetch joins
  in Doctrine) and enable Laravel's `Model::preventLazyLoading()` outside
  production.
