# Platform data, identity, and digital proof security

Load this technology-neutral module when the application consumes a shared
service, canonical register, public service, or digital proof, or makes an
eligibility/authorization decision from an external source. It supplements
framework-specific modules; it does not replace source inspection.

## Evidence and finding status

Inspect request fields, response models, scopes, policies, caches, logs,
telemetry, proof validation, and fallback paths. Cite the repository-relative
file, line range, configuration, test, or observable trace for every claim.

- **Confirmed** means current evidence demonstrates the security condition or
  exploit path.
- **Probable** means evidence shows a likely condition but an intermediate
  control remains unverified.
- **Informational** means a hardening recommendation or an undocumented
  design gap without a demonstrated exploit path.
- A missing policy, owner, or design record is not a confirmed vulnerability.
  Record it as `Unknown` or `Informational` unless code evidence demonstrates
  harmful behavior.

Use the approved severity scheme: **Critical**, **High**, **Medium**,
**Low**, and **Informational**. Severity describes impact; status describes the
quality of evidence.

## Data minimization and scoped questions

For each shared or canonical data flow, verify:

1. The request asks only the fields needed for the stated purpose.
2. The provider enforces purpose, subject, tenant, audience, and authorization
   scope; a client-side filter is not sufficient.
3. Responses, exports, caches, logs, traces, analytics, and error messages do
   not over-fetch or retain unnecessary personal or restricted data.
4. A narrow question or decision API is preferred over bulk records or a
   replicated broad dataset when the use case needs only an answer.
5. Data custodian, retention, permitted use, and open/shared/closed status are
   evidenced rather than assumed.

## Pairwise correlation risk

Check whether identifiers, proof subjects, timestamps, attributes, or stable
cross-service keys allow unrelated relying parties to link a person or
activity. Prefer pairwise or purpose-specific identifiers where correlation is
not required. Verify that logs and error responses do not reintroduce a
global identifier. Treat correlation risk as a finding only when the affected
data path and impact are evidenced.

## Digital proof properties

When a proof or credential influences a decision, inspect both issuance and
verification. Evidence should cover:

| Property | Required question |
|---|---|
| Audience | Is the proof valid only for the intended relying party or use? |
| Expiry | Is validity bounded and checked at the decision time? |
| Revocation | Can issuer withdrawal be checked or safely represented? |
| Replay resistance | Are nonce, freshness, one-time use, channel binding, or equivalent controls used where replay matters? |
| Minimal disclosure | Does the verifier receive only required claims? |
| Integrity and issuer | Are issuer, signature, algorithm, and key status validated using an approved trust path? |

Invalid, expired, revoked, and replayed proofs must not silently produce a
successful decision. Do not claim a proof is safe from its format or library
name alone; verify configuration and tests.

## Assurance levels and safe downgrade

Record the assurance level required for each operation and the evidence that
the presented identity meets it. If a provider or proof service is unavailable,
an identity downgrade or fallback must:

- re-evaluate authorization for the lower assurance level;
- prohibit operations that require the higher level;
- avoid converting an unknown identity into an identified subject;
- clearly communicate the limitation to the operator or user where observable;
- preserve purpose scope, minimal disclosure, and audit context.

Do not classify a fallback as safe merely because it keeps the request
available.

## Audit context where observable

Where the application can observe the decision, record a privacy-preserving
audit event containing the event type, actor or service, subject reference,
purpose/audience, proof status or assurance level, source/version or
provenance, decision/outcome, reason code, and correlation identifier. Do not
log proof contents, tokens, unnecessary attributes, or raw personal data.
Document when a context item is unavailable rather than fabricating it.
