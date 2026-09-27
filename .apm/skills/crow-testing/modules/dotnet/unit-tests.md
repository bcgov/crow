# .NET unit tests

Applies when the repository has a `.sln`/`.slnx`/`.csproj`/`.fsproj`/`global.json`. Detect what already
exists before recommending anything.

## Study the existing suite before generating anything

If a test project already exists with real tests in it, **read a representative test class, its base classes,
and any `Builders/`, `Suites/`, or `Utilities/` helpers before writing code.** Conventions live in the code,
not the package list — the shape of an existing suite (shared abstract suites, builder style, diagnostics
setup) should override this module's defaults. State any deliberate deviation and why.

**Match the structure, not the vintage.** Follow the existing suite's infrastructure decisions exactly, but
write new tests to the project's declared style (`.editorconfig`) and the idiom its target framework
supports — an older C# style in the surrounding files records when they were written, not a decision to keep
writing that way. See
[`../reference/language-features-for-testability.md`](../reference/language-features-for-testability.md).

## Detect first, default second

1. Look for an existing test project and its frameworks (xUnit/NUnit/MSTest), assertion library
   (FluentAssertions, built-in asserts, Shouldly, etc.), validation library (FluentValidation or none), and
   test-data generation approach already in use. Concretely: check `.sln`/`.slnx` for test projects,
   `.csproj`/`.fsproj`/`Directory.Packages.props`/`Directory.Build.props` for `PackageReference` entries
   (`xunit`, `xunit.v3`, `nunit`, `mstest`, `FluentAssertions`, `CsCheck`, `FsCheck`, `Bogus`, `AutoBogus`,
   `FluentValidation`), and skim an existing test file's `using`s/attributes (`[Fact]`/`[Test]`/`[TestMethod]`)
   to confirm which framework is actually wired up versus merely referenced. Judge whether it's
   **meaningfully existing** — a real suite with multiple tests exercising actual behavior — or
   **effectively empty** (only a framework's scaffold/example test, or 1-2 trivial tests). A
   meaningfully-existing choice should be followed, not competed with. An effectively-empty one does not
   lock anything in: you may still default normally (step 2) and suggest it explicitly, framed as
   overridable ("I see only a placeholder NUnit test — I'd suggest starting fresh with xUnit.v3/CsCheck
   since nothing is established yet; say the word to keep NUnit instead").
2. **Only when there is no test project yet** (a brand-new .NET project with nothing to detect), default to:
   - **xUnit.v3** as the test framework (`xunit.v3` NuGet package). v3 requires .NET 8.0+ or .NET Framework
     4.7.2+ and produces executable test projects on
     [Microsoft.Testing.Platform](https://learn.microsoft.com/dotnet/core/testing/microsoft-testing-platform-intro)
     rather than DLLs run by an external adapter. If the target project's TFM is below v3's floor and
     cannot be raised, fall back to the v2 line (`xunit` NuGet package) and record the reason.
   - **`Microsoft.Testing.Extensions.TrxReport`** on the same test project when CI needs a portable TRX
     result file. MTP does not emit TRX out of the box. See "CI test-result publishing (MTP)" below.
   - **CsCheck** for property-based testing of validation rules and invariants with many input combinations
     (see [`reference/property-based-testing.md`](../reference/property-based-testing.md) for generator and
     shrinking patterns — load only when actually writing a property-based test).
   - **Bogus** for realistic fake test data via a builder per model, seeded for reproducibility
     (`new Faker<T>(locale).UseSeed(_seed)` with an explicit `.RuleFor(...)` per constrained field). **Do
     not introduce AutoBogus in new tests** — choose Bogus categories deliberately
     (`f.Name.LastName()`, `f.Phone.PhoneNumber()`, `f.Random.Int(1, 10000)`) so domain constraints stay
     visible in the builder rather than delegated to reflection-based auto-population.
3. **When AutoBogus is already in the existing suite:** it stays in the detection list (step 1) so the
   agent recognizes it and does not fight it wholesale. Then assess replacement effort: if the swap is a
   simple, low-risk replacement — `new AutoFaker<T>(locale).UseSeed(_seed)` becomes
   `new Faker<T>(locale).UseSeed(_seed)`, every field of interest already has an explicit `.RuleFor`, and
   there is no substantial `AutoFaker.Configure` alias registry — recommend migrating, add explicit
   `.RuleFor(...)` for anything previously auto-populated, remove the `AutoBogus` `PackageReference`, and
   delete alias setup. If the migration is non-trivial (heavy reliance on reflection auto-population or a
   large alias registry), leave the existing suite in place. **New tests must never introduce AutoBogus**
   regardless of what the surrounding suite uses.
4. **When the existing suite is on xUnit v2 (`xunit` package):** offer to migrate to xUnit.v3 rather than
   silently following v2. Load the
   [`xUnit v2 to v3 migration`](../reference/xunit-v2-to-v3-migration.md) playbook to assess cost, then
   ask the user to confirm before applying its migration steps. New tests must not land on v3 alongside a
   still-v2 suite unless the user explicitly chooses that mixed path.

5. **Do not default to FluentValidation, FluentValidation.TestHelper, or FluentAssertions.** These are only
   appropriate when the project already uses FluentValidation for its validation rules. If it doesn't,
   propose whatever validation/assertion approach fits what's already there — built-in xUnit asserts are a
   perfectly good fallback.

### xUnit v3 cancellation and xUnit1051

This guidance applies **only to xUnit v3 suites**. Do not use `TestContext.Current.CancellationToken` or
apply xUnit1051 advice to a retained xUnit v2 suite; load the v2-to-v3 migration module when assessing a
migration instead.

At responsive async boundaries in test methods, pass `TestContext.Current.CancellationToken` when a
service, repository, validator, database, network, or workflow API accepts a `CancellationToken`. This
satisfies xUnit1051 and lets a hung dependency, SQL command, or workflow stop with the test timeout
instead of blocking the runner. Never pass `TestContext.Current` into production code.

Do not add token boilerplate solely to fast, deterministic assertion queries such as `SingleAsync(...)` or
`CountAsync(...)` used to verify a row written by the test. If the query can scan, wait on locks, or block
materially, pass the context token. Otherwise use the narrowest statement/member-level xUnit1051
suppression available, with a local rationale; never suppress the rule at file, class, or project scope.

`TestContext.Current` is `AsyncLocal`. Background work may outlive the test or may not inherit the
execution context when flow is suppressed, so capture the token before starting that work and pass the
captured token explicitly. The parameterless xUnit v3 `IAsyncLifetime.InitializeAsync` and
`DisposeAsync` methods do not receive a per-test token: when `TestContext.Current` is available there, it
represents the fixture lifetime, not an individual test; otherwise use a fixture-owned, bounded
`CancellationTokenSource` for cancellable setup/teardown rather than inventing a test token.

## CI test-result publishing (MTP)

MTP does not emit TRX by default. Add `Microsoft.Testing.Extensions.TrxReport` when CI needs a TRX file,
then invoke:

```sh
dotnet test -- --report-trx --report-trx-filename Results.trx
```

The `--` separator is required because MTP flags come after `dotnet test` arguments. The file lands under
the project's `TestResults\` folder unless the filename specifies a path.

Pipelines that relied on the Azure DevOps `.NET Core v2` task's **Publish test results** checkbox must
move publishing to a separate step: uncheck that option and add `PublishTestResults@2` or the Classic
**Publish Test Results** task using VSTest format and a pattern such as `**/TestResults/*.trx`. The
VSTest format is correct even though MTP produced the file; the on-disk TRX shape is identical.

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
- **`{Entity}TrimmingTests.cs`** — kept deliberately separate as the *single source of truth* for model
  normalization/trimming across every string property, so adding a new trimmed property has one obvious
  home instead of being scattered across per-field files.
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
- For CsCheck property-based tests, call `Sample` directly (no wrapper) and by default omit the `seed:`
  argument so each CI run explores new inputs. The `seed:` argument pins iteration 1 only, not the whole
  run — reproducibility of failures comes from CsCheck's shrinker reporting a reproducing seed, which you
  then promote to a pinned regression test. See
  [`reference/property-based-testing.md`](../reference/property-based-testing.md) for the seed section,
  iteration counts (100 default, 20 for narrow boundary properties), and the two-build (PR + nightly
  `CsCheck_Iter=1000`) strategy. This determinism model is different from the Bogus builders above:
  builders still use a fixed seed so fixture defaults reproduce; CsCheck properties do not.
- Group long test classes with `#region` blocks and give each class a short XML doc comment stating its
  purpose — these files are read far more often than they're written.

## Diagnostics

### Whitespace-sensitive validation

Keep model normalization and validator enforcement as separate test concerns:

- If the model trims string properties, cover that behavior in the model's
  `{Entity}TrimmingTests.cs` single-source-of-truth file.
- If a validator must reject whitespace-only input, test the validator directly even when the UI or
  model usually trims it first. A non-UI caller may bypass that normalization.

For a whitespace-sensitive validator rule, use this compact baseline matrix rather than testing only
ASCII spaces: spaces (`"   "`), tab (`"\t"`), newline (`"\n"`), carriage-return/newline (`"\r\n"`), and
mixed whitespace (for example `" \t \n "`). Derive each case's expected validity from the field and
validator contract; do not assume every field must reject every whitespace character. If the contract
claims to handle all whitespace, add relevant Unicode cases such as non-breaking or ideographic spaces.
For an optional field, also assert that `null` and empty string retain their intended validity when the
contract permits them. Keep these cases with the field's validator tests; do not move them into trimming
tests unless the behavior under test is model normalization. For broad character/Unicode invariants,
pair these readable examples with a property-based test as described in
[`../reference/property-based-testing.md`](../reference/property-based-testing.md).

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
`design-smell-entries.md` DDD/F# smells (illegal states representable, exhaustive matching) structural
rather than optional, so testing effort there is usually better spent on the boundary between F# and any
C#-consuming code than on re-validating invariants the type system already guarantees.
