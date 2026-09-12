# Shared-validator test layering

Load when one validation contract is extracted into a shared validator and consumed by two or more
model validators.

## Required two-layer strategy

Use exactly two test layers:

1. **One exhaustive suite against the shared validator directly.**
   - Use a minimal test-double model that implements the validator interface.
   - Put all format, length-boundary, property-based, Unicode, edge-case, valid, and invalid examples here.
   - Name the class after the shared validator, such as `EmailModelValidatorTests`.
   - Keep the suite beside the shared validator's tests or its abstract test-suite base.
2. **Thin wiring-and-context smoke tests for every consuming model.**
   - Prove the consumer still calls the shared validator.
   - Prove any consumer-specific conditional wrapper or context is applied correctly.
   - Usually use two or three cases: a representative valid/invalid wiring case and any applicable condition
     true/false cases.
   - Do not repeat exhaustive rule coverage. More than a few cases is a signal to move assertions into the
     direct shared-validator suite.

## Why this split matters

Running the same exhaustive rule matrix through every consumer repeats the same rule object and increases
runtime and maintenance cost without adding defect-detection value. Omitting consumer smoke tests is also
unsafe: a consumer can silently stop calling the shared validator, or wrap it in the wrong condition.

## Do not use

- A full inherited suite that reruns every shared-rule scenario for each consumer.
- A single direct shared-validator suite with no consumer wiring tests.
- A manual-only label for a scenario that the existing test infrastructure can automate.

If consumer behavior genuinely differs, keep the shared contract tests exhaustive and add only the
consumer-specific assertions needed to prove that difference.
