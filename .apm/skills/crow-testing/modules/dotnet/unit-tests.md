# .NET unit tests

Applies when the repository has a `.sln`/`.slnx`/`.csproj`/`.fsproj`/`global.json`. Detect what already
exists before recommending anything.

## Detect first, default second

1. Look for an existing test project and its frameworks (xUnit/NUnit/MSTest), assertion library
   (FluentAssertions, built-in asserts, Shouldly, etc.), validation library (FluentValidation or none), and
   test-data generation approach already in use. Concretely: check `.sln`/`.slnx` for test projects,
   `.csproj`/`.fsproj`/`Directory.Packages.props`/`Directory.Build.props` for `PackageReference` entries
   (`xunit`, `nunit`, `mstest`, `FluentAssertions`, `CsCheck`, `FsCheck`, `Bogus`, `AutoBogus`,
   `FluentValidation`), and skim an existing test file's `using`s/attributes (`[Fact]`/`[Test]`/`[TestMethod]`)
   to confirm which framework is actually wired up versus merely referenced. Judge whether it's
   **meaningfully existing** — a real suite with multiple tests exercising actual behavior — or
   **effectively empty** (only a framework's scaffold/example test, or 1-2 trivial tests). A
   meaningfully-existing choice should be followed, not competed with. An effectively-empty one does not
   lock anything in: you may still default normally (step 2) and suggest it explicitly, framed as
   overridable ("I see only a placeholder NUnit test — I'd suggest starting fresh with xUnit/CsCheck since
   nothing is established yet; say the word to keep NUnit instead").
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

## Test project layout

Once more than one model or feature is under test, structure matters more than it looks. A layout that has
held up well:

```
Tests/
├── Validators/
│   ├── Suites/                       # Reusable abstract suites (one per field type)
│   │   ├── EmailValidationTestSuite.cs
│   │   └── AddressValidationTestSuite.cs
│   ├── EditWorker/
│   │   ├── EditWorkerSmokeTests.cs           # start here: "does it work at all?"
│   │   ├── EditWorkerEmailFieldsTests.cs     # thin subclass of a shared suite
│   │   ├── EditWorkerPersonalInfoFieldsTests.cs  # fields unique to this model
│   │   ├── EditWorkerTrimmingTests.cs        # single source of truth for trimming
│   │   └── CrossField/
│   │       ├── NameInterdependencyTests.cs
│   │       └── DeceasedWorkerRulesTests.cs
│   └── PreIqWorker/                  # same shape per model
├── Builders/                         # one builder per model
└── Utilities/                        # generators and shared test helpers
```

The file taxonomy per model, and why each exists:

- **`{Entity}SmokeTests.cs`** — fast sanity checks: the builder's defaults are valid, a fully-populated model
  is valid, a minimal model is valid, and each common valid scenario passes. Run these first when changing
  anything; they answer "is this broken at all?" in seconds, and they double as documentation of what a valid
  model looks like. Include a `[Fact(Skip = "Development scratchpad")]` slot for quick iteration.
- **`{Entity}{Field}FieldsTests.cs`** — either a ~40-line subclass of a shared suite (for field types that
  repeat across models) or a normal test class (for fields unique to this model).
- **`{Entity}TrimmingTests.cs`** — kept deliberately separate as the *single source of truth* for whitespace
  handling across every string property on the model, so adding a new trimmed property has one obvious home
  instead of being scattered across per-field files.
- **`CrossField/*Tests.cs`** — rules spanning more than one field (mutual requirements, conditional
  requirements, interdependencies). These are model-specific by nature and don't belong in a shared suite.

Organize by *field/behavior*, not by test technique — don't create parallel "PropertyBasedTests" and
"TraditionalTests" trees. Both techniques belong in the same file, next to the rule they cover.

When the same field type or contract appears on three or more models, hoist its tests into an abstract
generic suite instead of copying files — see
[`reference/reusable-test-suites.md`](../reference/reusable-test-suites.md).

## Test structure

- One test class per unit of behavior; builder classes for constructing test subjects with sensible
  defaults so each test only sets what it's testing.
- Smoke tests for the "everything valid" case, plus one test per validation rule/branch.
- Keep test data builders deterministic (fixed seed) so failures reproduce exactly. Builder defaults must
  themselves produce a valid object, and that contract deserves its own test — see
  [`reference/test-data-builders.md`](../reference/test-data-builders.md) for the full pattern (generated
  defaults with pinned domain constraints, semantic composite methods, nested composition, thread safety).
- Group long test classes with `#region` blocks and give each class a short XML doc comment stating its
  purpose — these files are read far more often than they're written.

## Diagnostics

Inject the test framework's output helper (xUnit: `ITestOutputHelper`) into test classes and write the input
under test before asserting:

```csharp
Output.WriteLine($"Testing valid email: {email}");
result.ShouldNotHaveValidationErrorFor(EmailExpression);
```

This is what makes a randomly-generated or shrunk property-based failure diagnosable after the fact rather
than a bare "assertion failed". Pair it with a `ToString()` override on models used in tests so
`Output.WriteLine($"{model}")` prints something worth reading.

## Context-dependent validation

When the same validator behaves differently depending on context — named rule sets, a caller-supplied mode,
or a feature flag — the context is itself a test dimension. Cover the matrix explicitly: for each context,
assert both the rules that apply *and* the rules that deliberately don't. A rule that is supposed to relax in
one context is exactly the kind of thing that silently stops relaxing, and only a test naming that context
will catch it.

## F# projects

Everything above still applies (xUnit runs F# test projects the same way; CsCheck works from F# too). Two
F#-specific notes: prefer **FsCheck** over CsCheck when the project is F#-first and already leans on
FsCheck's idioms (its `Arbitrary`/`Gen` API is more natural from F# than CsCheck's fluent C# API — detect
first, same rule as everything else here); and F#'s discriminated unions/records already make many of the
`design-smell-catalog.md` DDD/F# smells (illegal states representable, exhaustive matching) structural
rather than optional, so testing effort there is usually better spent on the boundary between F# and any
C#-consuming code than on re-validating invariants the type system already guarantees.
