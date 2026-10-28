# Stateful operation scenarios

Use the relevant IDs from
[`stateful-invariants.md`](../../crow-application-architecture/modules/stateful-invariants.md)
to derive expected behavior from a sourced rule, not from an assumed
implementation. Choose the lowest test level that can detect the failure as
described in [`foundation.md`](foundation.md).

Cover permitted and forbidden transitions (including terminal and recovery
states), denied cross-tenant access through alternate entry points,
duplicate/replayed delivery, and failure between effects as applicable. For
balances and races use separate connections with a barrier or deterministic
fault injection; assert the conservation property, checked conflict result,
and retry behavior. Include missing tenant context, policy-store failure,
rollback, and resource cleanup. Pure transition decisions can use unit tests;
locking, constraints, RLS/VPD and transaction behavior need a real isolated
persistence boundary.

Run write-capable race or replay checks only after user approval against a
reviewer-created local container/in-memory store or explicitly confirmed
disposable target. Never reuse discovered connection strings or credentials,
and never execute against production or shared staging. If there is no safe
target, record the unverified scenario rather than claiming a passing test.
