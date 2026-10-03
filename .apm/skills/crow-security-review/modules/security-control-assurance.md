# Module: Security Control Assurance

**Purpose:** Link security controls and findings to executable tests and CI
gates without replacing the Crow testing workflow.

## Control matrix

For each authentication, authorization, anti-forgery, validation, cryptographic,
credential (including revocation), audit, safe-degradation, and
security-relevant data retention or deletion control, record:

| Control | Enforcement point | Unit test | Integration test | Negative case | CI gate | Status |
|---|---|---|---|---|---|---|

For each test cited as control evidence, inspect its arrange/act/assert path
against the production enforcement point. Verify that the act invokes the
production method or exercises its real framework/host entry point, and that
the assertions observe the resulting behavior or effects. Trace through
helpers, mocks, and callbacks: a mock may supply inputs or observe
collaborators, but a callback or inline sequence that implements the control
instead of calling production code does not validate that control. Do not
credit a test that independently performs the same deletion, token revocation,
authorization decision, or other security behavior and then asserts on its own
effects. Exclude that test as evidence, assess any other tests, then mark the
control `Verified`, `Gap`, or `Unknown` as appropriate. Cite the test and
production locations for a gap and pass replacement-test requirements to
`crow-testing`. A test may still cover a different control it actually invokes;
do not discard valid evidence merely because it uses helpers or mocks.

Direct controller or handler construction does not prove framework middleware,
filters, routing, authentication schemes, authorization policies, or
anti-forgery behavior. Require an integration test when assurance depends on
real framework wiring.

Check at minimum:

- unauthenticated and unauthorized denial;
- cross-user or cross-tenant access;
- expiry, revocation, replay, and malformed credentials;
- invalid input bounds and resource-exhaustion limits;
- fail-closed dependency behavior;
- audit-event emission and redaction;
- negative cryptographic verification;
- security middleware order and endpoint metadata.

## CI gate review

Inventory tracked pipeline files and distinguish:

- a tool invocation;
- a report upload;
- an enforcing gate that can fail the pipeline.

Flag placeholder or success-only steps, such as a coverage-threshold step that
only echoes success. Record absent repository pipeline controls as scoped
observations; organization-level or platform-native controls remain `Unknown`
unless queried directly.

Run `scripts/Find-CrowSecurityCiGates.ps1` to produce deterministic candidates,
then verify each candidate against pipeline semantics before reporting it. Its
`candidateObserved` values are pattern observations, not proof that a tool or
threshold can fail the pipeline.

## Testing handoff

The security review owns control identification and assurance gaps. The
`crow-testing` skill owns test design and implementation. For each actionable
gap, pass:

- finding or control ID;
- enforcement point and evidence;
- required positive and negative behavior;
- required test level;
- relevant trust boundary and failure mode.

Do not set a universal coverage percentage as a substitute for control-path
coverage.
