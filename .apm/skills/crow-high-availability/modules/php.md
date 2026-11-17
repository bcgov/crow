# PHP continuity deltas

Identify framework/version and web-server/SAPI model before using PHP-FPM
guidance. Reuse [PHP web architecture](../../crow-application-architecture/modules/php-web.md)
and [PHP implementation](../../crow-application-development/modules/php/web.md).

## Web requests and FPM

- Inspect pool ownership, process/connection limits, request timeouts, shared
  sessions, session locking and keys. Include old/new serialization behavior.
- Establish how an immutable release becomes visible to each worker. Assess
  realpath/OPcache/preload state and old/new code mixing; a symlink switch or
  successful cache clear alone does not establish request consistency.
- Verify the actual FPM/web-server reload and drain behavior and routing
  propagation. Include long requests and shared-pool blast radius.
- Keep uploaded/session files separate from replaceable code and retain
  versioned assets for already-open clients.

## Persistent workers

CLI queue daemons, schedulers and long-running application servers have a
different lifetime from request-scoped FPM work. Assess stop-acquisition,
active-job completion/checkpoint, leases, replay, idempotency, code/config
refresh and scheduled-job overlap independently. Do not assume a web reload
updates these processes.

No in-place dependency installation or speculative restart commands belong in
this design. The existing update/application owners implement approved changes.
Use version-appropriate [FPM configuration](https://www.php.net/manual/en/install.fpm.configuration.php)
and [OPcache configuration](https://www.php.net/manual/en/opcache.configuration.php)
sources, with review dates recorded in the report.
