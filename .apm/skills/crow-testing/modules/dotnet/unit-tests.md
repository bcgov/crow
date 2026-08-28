# .NET unit tests

Applies when the repository has a `.sln`/`.slnx`/`.csproj`/`.fsproj`/`global.json`. Detect what already
exists before recommending anything.

## Detect first, default second

1. Look for an existing test project and its frameworks (xUnit/NUnit/MSTest), assertion library
   (FluentAssertions, built-in asserts, Shouldly, etc.), validation library (FluentValidation or none), and
   test-data generation approach already in use. Judge whether it's **meaningfully existing** — a real
   suite with multiple tests exercising actual behavior — or **effectively empty** (only a framework's
   scaffold/example test, or 1-2 trivial tests). A meaningfully-existing choice should be followed, not
   competed with. An effectively-empty one does not lock anything in: you may still default normally
   (step 2) and suggest it explicitly, framed as overridable ("I see only a placeholder NUnit test — I'd
   suggest starting fresh with xUnit/CsCheck since nothing is established yet; say the word to keep NUnit
   instead").
2. **Only when there is no test project yet** (a brand-new .NET project with nothing to detect), default to:
   - **xUnit** as the test framework.
   - **CsCheck** for property-based testing of validation rules and invariants with many input combinations
     (see [`reference/property-based-testing.md`](../reference/property-based-testing.md) for generator and
     shrinking patterns — load only when actually writing a property-based test).
   - **Bogus** / **AutoBogus** for realistic fake test data via a builder per model, seeded for
     reproducibility (`AutoFaker<T>().UseSeed(_seed)`).
3. **Do not default to FluentValidation, FluentValidation.TestHelper, or FluentAssertions.** These are only
   appropriate when the project already uses FluentValidation for its validation rules. If it doesn't,
   propose whatever validation/assertion approach fits what's already there — built-in xUnit asserts are a
   perfectly good fallback.

## Test structure

- One test class per unit of behavior; builder classes for constructing test subjects with sensible
  defaults so each test only sets what it's testing.
- Smoke tests for the "everything valid" case, plus one test per validation rule/branch.
- Keep test data builders deterministic (fixed seed) so failures reproduce exactly.
