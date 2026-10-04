# Conditional decision, data, and service responsibilities

Load only the sections that apply: an application may affect a person's
outcome, hold or derive information, or offer a service through multiple
channels. These are design questions, not evidence that a particular policy,
data-sharing authority, or review process has been approved. Record the
accountable owner and `Unknown` where authority or implementation is not
established; do not claim compliance from a proposed design.

## Decisions affecting people

When software produces, recommends, or changes an outcome affecting a person:

- Distinguish routine process automation, decision support, and an automated
  decision; trace the consequential path, including embedded third-party AI.
- Identify the decision owner, governing assessment or approval, and the
  reason and source evidence that can be retained without exposing sensitive
  information. Separate a recommendation from a final determination.
- Define how an affected person learns of the decision, corrects an error or
  challenges it, and reaches an accountable human reviewer when required.
  Identify the operational owner of that path rather than assuming staffing.
- Define how a review can correct the outcome and propagate any correction to
  downstream consumers. Test the challenge path, not just the initial decision.

Do not presume every automated workflow requires an appeal or that a model's
explanation alone establishes a lawful or fair decision.

## Information lifecycle

For each relevant store, including caches, logs, search or analytics copies,
backups, and non-production data, record the data's classification, purpose,
location/residency, retention or approved records schedule, and disposition or
legal-hold behavior. Include material third-party processing locations and
subprocessors where known; mark unverified claims `Unknown`.

Identify the authoritative source and steward for derived copies. Record
copy direction, freshness bound, reconciliation or invalidation, and how a
correction at the source reaches consumers. Do not silently edit a derived
copy as though it were authoritative. Record the legal authority or approval
for collection, reuse, or disclosure when applicable; do not infer it from
technical access or present a requested approval as granted.

Where Indigenous identity or community data is handled, determine whether
specific data-governance obligations apply and who has authority to establish
them. Preserve the ability to segregate, correct, export, or dispose of data
where those requirements are confirmed. Do not equate Indigenous-language
text support with data governance or impose one governance model on all
systems.

## Continuity across channels

When a service offers multiple digital or assisted channels, keep case state
and outcomes consistent independently of the presentation channel. Define
who may resume or act on a case and test beginning in one channel and
continuing in another without losing progress or unnecessarily repeating
information.

Where a fact is available from an authoritative source, verify purpose,
authority, access, and freshness before presenting it for confirmation rather
than asking for re-entry. Provide a correction route back to the source.
Where reuse is not lawful or feasible, explain the constraint and retain an
appropriate collection path; do not build a standing consolidated profile by
default.

For long forms or unreliable connectivity, consider save-and-resume and an
assisted alternative where the service offers one. Do not require offline
synchronization or provision a human channel that the service owner has not
committed to operate.
