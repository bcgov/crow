# Module: Security Logging and Audit

**Purpose:** Detect missing, incomplete, misleading, or privacy-unsafe security
event records across entry points, policy handlers, services, and authoritative
state changes.

## Event inventory

When the application has authentication, authorization, privileged
administration, credentials, tokens, sensitive exports, or destructive
operations, trace each lifecycle end to end.

| Lifecycle | Required events to inspect |
|---|---|
| Authentication | success, failure, lockout/throttle, external-provider error, logout/revocation |
| Authorization | denial, policy failure, exceptional bypass, privilege use |
| Privilege | grant, revoke, bootstrap, last-admin protection, delegated administration |
| Credentials and tokens | issue, one-time disclosure, failed use, expiry, rotation, revoke, purge |
| Sensitive data | export, bulk access, deletion, retention purge, recovery |
| Security configuration | policy, key, trust, allowlist, or enforcement changes |

Inspect both request-facing code and the authoritative service or persistence
method. Controller-only logs can be bypassed by workers, alternate endpoints,
or future callers; service-only logs may omit the actor and request context.
Record where the authoritative event is emitted and how actor context reaches
it.

## Minimum useful event

Verify that an event can answer:

- what happened and whether it succeeded;
- actor or workload identity using a non-sensitive stable identifier;
- target resource or subject;
- timestamp and correlation/trace identifier;
- reason or policy outcome;
- source channel where useful;
- before/after privilege state when appropriate.

Do not require secret values, raw tokens, session IDs, email addresses, display
names, or unnecessary claim sets. Review structured message templates,
exception serialization, and diagnostic scopes for PII or credential leakage.

## Detection method

1. Inventory security-sensitive methods and policy decisions.
2. Trace all callers, including workers and maintenance paths.
3. Search for logger, audit sink, event publisher, or platform audit calls.
4. Verify that early returns, failures, and exceptions produce an appropriate
   event without leaking sensitive data.
5. Distinguish event creation from retention, alerting, integrity protection,
   and access control; report each gap separately.
6. Check tests for event emission, redaction, and failure-path coverage.

Absence in application source does not prove that an identity provider,
gateway, cloud platform, or SIEM lacks an event. Scope the finding to the
observable layer and record external coverage as `Unknown`.

## Severity guidance

- High: undetectable privileged state change or credential abuse with material
  impact and no observed compensating audit source.
- Medium: missing security lifecycle events that materially hinder detection or
  attribution.
- Low: incomplete fields, inconsistent correlation, or local hygiene weakness.
- Informational: retention, ownership, or alerting policy is undocumented but
  harmful behavior is not evidenced.
