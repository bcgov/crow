# Property-based testing patterns (CsCheck)

Deeper guidance for writing property-based tests with CsCheck. Load only when actually authoring one.

**Prerequisites:** add the `CsCheck` NuGet package to the test project. The generator templates below
target a modern .NET TFM; if the project targets .NET 5 or earlier, drop or replace any `TimeOnly`/`DateOnly`
generators in `GenDateExtensions.cs` (introduced in .NET 6) with `DateTime`-based equivalents. The
`ReplaySeed` samples use `string?`, so nullable reference types must be enabled in the test project (the
default in modern SDK templates). The date generators are relative to today by design; a case that needs
exact dates belongs in a `[Fact]`/`[Theory]`, not a property test.

## When to reach for a property-based test

Use it for invariants that must hold across a **wide, hard-to-enumerate space of inputs** — not for a
single boundary check. A rule like "strings longer than 50 characters are rejected" is a poor property-based
candidate: three ordinary example tests (49, 50, 51 characters) already cover it completely and are easier
to read. Property-based testing earns its keep for things like:

- **Format/character-class invariants** that must hold for *any* input, not just a few boundary lengths
  (e.g. "the sanitized filename only ever contains `[a-z0-9-]`", "the slug never ends in a dash", "the
  output is always lowercase", regardless of what Unicode, punctuation, or whitespace went in).
- **Structural invariants** ("round-tripping through the mapper never loses a required field", "the result
  is never null for non-null input", "repeated calls with the same input are idempotent").
- **Regex/parsing rules** where the interesting bugs are in unusual character combinations a human wouldn't
  think to enumerate by hand (accented letters, homoglyphs, right-to-left scripts, exotic whitespace).

## Core pattern

Call `Sample` directly from CsCheck — no wrapper. **Every property test declares a `ReplaySeed` local that is
`null` by default**, passes it to `Sample`, and ends with a guard that fails if it is still set. Normal runs
explore new inputs; when a run fails, the developer pastes the reported seed into that one variable and
re-runs just that test (see [Reproducing a failure](#reproducing-a-failure-paste-the-seed-run-one-test)).

```csharp
[Fact]
public void SanitizedName_NeverEndsWithDash()
{
    string? ReplaySeed = null;   // paste the seed from a failure here to replay it; revert after the fix

    Gen.String[1, 200].Sample(input =>
    {
        var result = Sanitize.DownloadFileName(input);
        if (!string.IsNullOrEmpty(result))
            Assert.NotEqual('-', result[^1]);
    }, seed: ReplaySeed, iter: ReplaySeed is null ? Check.Iter : 1);

    Assert.True(ReplaySeed is null, "ReplaySeed is still set; revert it to null before committing.");
}

[Fact]
public void SanitizedName_OnlyContainsValidSlugCharacters()
{
    string? ReplaySeed = null;

    Gen.String[1, 200].Sample(input =>
    {
        var result = Sanitize.DownloadFileName(input);
        Assert.Matches(@"^[a-z0-9-]*$", result);
    }, seed: ReplaySeed, iter: ReplaySeed is null ? Check.Iter : 1);

    Assert.True(ReplaySeed is null, "ReplaySeed is still set; revert it to null before committing.");
}
```

- `seed: null` is a no-op and `Check.Iter` is CsCheck's default (100, or `CsCheck_Iter`), so an unreplayed
  test behaves exactly like a bare `Sample(...)`. With a seed set, `iter: 1` runs only the failing case
  (unset `CsCheck_Time`; it overrides `iter:`).
- **Design choice — isolated replay, with a guard against leftovers.** A seed pins one case, so replay uses
  `iter: 1`: it reproduces the exact case, the reported seed stays the same, and breakpoints hit once. (A bare
  `seed:` with default iterations is not isolated: it runs all iterations, shrinks, and reports a different
  seed.) The cost is that a forgotten seed would silently reduce the test to one case, so the trailing guard
  fails the test once the defect is fixed until the seed is reverted to `null`. While the failure is
  reproducing, the guard is never reached.
- Use a plain local, not `const`: a `const` null makes the `is null` checks raise CS8519/CS8520, which break
  builds that treat warnings as errors.
- Keep the variable local to each test so replaying one test never affects another.
- Compose generators (`Gen.Int`, `Gen.String`, `Gen.OneOf`, `Gen.Select`, `Gen.Frequency`) to build
  realistic domain objects instead of hand-rolling random values.
- A property-based test explores; a fixed seed gives repeatability of a single case, not broad exploration.
  Make each iteration valuable by shaping generators toward the domain's real partitions and known hazards:
  valid and invalid forms, duplicate values, cross-field dependencies, Unicode/normalization hazards, and
  boundary-adjacent values. Add explicit examples for named edge cases; do not expect more iterations from
  an unshaped generator to compensate for poor input coverage.
- Keep the property itself simple and obviously correct — a complicated property is as hard to trust as the
  code it's testing.
- Pair a small number of property-based tests (covering the general rule) with a handful of example-based
  tests (covering specific, named edge cases a reader will recognize).

## Reproducing a failure: paste the seed, run one test

When a property test fails, the output contains:

```
Set seed: "6qoQwbfBvu15" or -e CsCheck_Seed=6qoQwbfBvu15 to reproduce (0 shrinks, 0 skipped, 100 total).
```

1. Open the failing test (Test Explorer → failing test → Go to Test).
2. Set `string? ReplaySeed = "6qoQwbfBvu15";` (value copied from the message, quotes included).
3. Run or debug **just that test** in Visual Studio Test Explorer (or `dotnet test --filter "FullyQualifiedName~TestName"`).
   It fails on the same input every time, so breakpoints and fixes are repeatable.
4. Fix the defect, then promote the case to a permanent regression
   ([Regression pattern](#regression-pattern-for-a-discovered-failure)) and set `ReplaySeed` back to `null`
   (the test's trailing guard fails until you do). Non-null seeds stay only in `*_ReplayFromSeed` tests.

Alternative without editing code: `CsCheck_Seed=6qoQwbfBvu15` as an environment variable (or
`dotnet test -e CsCheck_Seed=...`). It applies to every property in the run, so combine it with a test
filter; in Test Explorer prefer the in-code `ReplaySeed` local.

## What `seed:` does (and does not) do

`seed:` / `CsCheck_Seed` are a **failure-replay handle, not a "deterministic CI/CD" switch**. Revalidate
against the CsCheck version in use when upgrading the dependency.

- `Sample(assertion, seed: X, iter: N)` generates iteration 1 from the PCG state of `X`; iterations 2..N run
  across worker threads, each seeded from `Stopwatch.GetTimestamp()`. A seed therefore pins **one case only**,
  not the run — hence `iter: 1` for replay.
- Reproducibility of a failure comes from the shrinker, which prints the seed of the *minimal failing case*.
  Replay it to investigate, then promote the minimized input to a permanent regression test
  ([Regression pattern](#regression-pattern-for-a-discovered-failure)).
- Committed tests keep `ReplaySeed = null` (enforced by the trailing guard), so every CI run explores new
  inputs and coverage compounds. A
  descriptive seed is not documentation of intent; put intent in the test name and generator composition.

> **Common pitfall: Bogus and CsCheck use seeds in opposite ways.**
>
> | | Bogus builders (`UseSeed(_seed)`) | CsCheck properties (`seed:` / `CsCheck_Seed`) |
> |---|---|---|
> | Purpose | Deterministic fixtures, identical every run | Temporary replay handle for a reported failure |
> | Scope | Pins the entire generated sequence | Pins **only the first case** |
> | Committed value | A fixed seed constant | `null` (explore new inputs every run) |
>
> **A CsCheck seed is never a determinism switch.** A developer used to Bogus may assume that setting one makes
> a property test repeatable; it doesn't, because the remaining iterations still vary. Use it only to replay a
> failure (with `iter: 1`), then reset `ReplaySeed` to `null`; the trailing assertion fails a test that still
> has one set. Conversely, keep Bogus builders seeded so fixtures stay reproducible. See
> [`test-data-builders.md`](test-data-builders.md).

## Iteration counts

- **General property tests:** `iter: ReplaySeed is null ? Check.Iter : 1` (default 100, scaled by
  `CsCheck_Iter`). See [Two-build strategy](#two-build-strategy-pr-run-vs-nightly-run).
- **Narrow, already-biased property spaces** (for example, varied invalid email forms just beyond a length
  threshold): `iter: ReplaySeed is null ? 20 : 1`. A literal count does not scale with the nightly env var,
  which is intended — a narrow space does not benefit from more iterations.

- **Exact threshold boundaries** (`N-1`, `N`, `N+1`) stay as ordinary example tests, not property tests.
  See [Pair properties with explicit boundary examples](#pair-properties-with-explicit-boundary-examples).
- The generator's bias and partition coverage matter more than raw volume; raise counts only when the state
  space and runtime justify it.

## Pair properties with explicit boundary examples

For any rule with a threshold, write **both**: the three boundary examples (N-1, N, N+1) as ordinary tests,
and a property covering the space on either side. The examples pin the exact boundary in a form a reviewer
can verify at a glance and a failure names precisely; the property covers the range the examples don't. A
property alone tends to under-sample the boundary — the single most likely place for an off-by-one — while
examples alone say nothing about the other 200 characters.

```csharp
[Fact]
public void Email_At_Exact_200_Chars_Should_Pass()   // boundary example, exact and readable
{
    var email = new string('a', 188) + "@example.com";
    Assert.Equal(200, email.Length);
    Validator.TestValidate(BuildModelWithEmail(email))
             .ShouldNotHaveValidationErrorFor(EmailExpression);
}

[Fact]
public void Property_Email_Exceeding_200_Chars_Always_Fails()   // the space beyond it
{
    string? ReplaySeed = null;

    Gen.String[Gen.Char.AlphaNumeric, 210, 260].Sample(local =>
    {
        var model = BuildModelWithEmail(local + "@test.com");
        Validator.TestValidate(model).ShouldHaveValidationErrorFor(EmailExpression);
    }, seed: ReplaySeed, iter: ReplaySeed is null ? 20 : 1);

    Assert.True(ReplaySeed is null, "ReplaySeed is still set; revert it to null before committing.");
}
```

## Two-build strategy: PR run vs nightly run

Property-based tests belong in CI — dev-only exploration wastes their value. The standard shape is two
pipelines that share the same tests but exercise them differently.

- **PR / main pipeline:** CsCheck's default `Check.Iter = 100`. Fast feedback; any failure is reproducible
  from the reported seed.
- **Nightly pipeline:** set `CsCheck_Iter` (typical value: `1000`) to scale general property tests. Literal
  `iter:` counts (e.g. `20`) on narrow properties intentionally do not scale. Deeper exploration compounds
  coverage across nights.

Both pipelines use the same failure workflow (see
[Reproducing a failure](#reproducing-a-failure-paste-the-seed-run-one-test)). Determinism of the whole run is
neither required nor useful; each discovered failure is reproducible from the shrinker's reported seed.

### Running the test project with a larger iteration count

The nightly job (or an ad-hoc local run) sets `CsCheck_Iter` before `dotnet test`. It scales tests that use
`Check.Iter` (the `ReplaySeed` pattern) or omit `iter:`; literal counts such as `20` stay pinned.

**PowerShell (Windows CI agents, local exploration):**

```powershell
$env:CsCheck_Iter = "1000"
dotnet test
```

**Bash (Linux/macOS CI agents):**

```bash
CsCheck_Iter=1000 dotnet test
```

**`dotnet test` env-var passthrough** (useful when the test host does not inherit shell env vars; check
your SDK/test-host version supports `-e`):

```bash
dotnet test -e CsCheck_Iter=1000
```

**Per-`Sample` wall-clock budget alternative.** `CsCheck_Time` is measured **per `Sample` call**, not per
`dotnet test` run. A value of `5` means "each property may run up to 5 seconds"; a suite of 200 properties
therefore takes up to ~1000 seconds. Use it only when a specific property's per-case cost is highly
variable and a time budget is more predictable than a fixed iteration count. For typical millisecond-scale
validation properties, prefer `CsCheck_Iter`. `CsCheck_Time` overrides `iter:` entirely, so unset it when
replaying a seed (otherwise random cases keep running after the seeded one).

```bash
CsCheck_Time=5 dotnet test   # per property, NOT per suite
```

## Regression pattern for a discovered failure

After reproducing and debugging a failure
([Reproducing a failure](#reproducing-a-failure-paste-the-seed-run-one-test)), turn it into a durable
regression one of two ways:

- **Preferred: pin the minimized input as an example test.** Copy the shrunken input into a plain `[Fact]`
  with hardcoded values. Names the defect, needs no generator, and never varies:

  ```csharp
  [Fact]
  public void RejectsHomoglyphEmail_Regression()
  {
      var model = BuildModelWithEmail("аdmin@example.com");   // Cyrillic 'а' — was the shrunken failure
      Validator.TestValidate(model).ShouldHaveValidationErrorFor(EmailExpression);
  }
  ```

- **Alternative: labelled seed replay** when the shrunken input is generator-shaped or diagnosis needs the
  original PCG state. Pair the reported seed with `iter: 1` so the replay tests only the failing case,
  never an unrelated one:

  ```csharp
  [Fact]
  public void RejectsHomoglyphEmail_ReplayFromSeed()
  {
      string? ReplaySeed = "6qoQwbfBvu15";   // labelled regression; deliberately non-null, so no trailing guard

      Gen.String[1, 200].Sample(local =>
      {
          var model = BuildModelWithEmail(local);
          Validator.TestValidate(model).ShouldHaveValidationErrorFor(EmailExpression);
      }, seed: ReplaySeed, iter: 1);
  }
  ```

Either way, keep the exploring (`ReplaySeed = null`) general property alongside the pinned regression so exploration continues.

## Biased character generators (for string/format validation)

A uniform-random `Gen.String` under-samples the edge cases that actually cause bugs. A generator that biases
toward realistic input while still guaranteeing coverage of known-nasty characters catches more real bugs
per iteration. Below is a quick at-a-glance illustration of the idea:

```csharp
public static Gen<char> SmartLetter() =>
    Gen.Frequency(
        (50, Gen.OneOf(Gen.Char['a', 'z'], Gen.Char['A', 'Z'])),  // common case: plain ASCII
        (25, Gen.Char['\u00C0', '\u00FF']),                       // common: accented Latin-1
        (10, Gen.OneOfConst('і', 'ο', 'а')),                      // homoglyphs (security/spoofing)
        (10, Gen.OneOfConst('ı', 'İ', 'ß')),                      // normalization hazards (Turkish I, ß)
        (5,  Gen.OneOfConst('א', 'ا')));                          // RTL scripts (bidi handling)
```

**Don't just adapt this — copy the real, already-tested files.** `templates/dotnet/generators/` has three
ready-to-use generator utilities, tried and proven, that save you from regenerating (and re-introducing
mistakes into) this kind of code from scratch:

- `GenCharExtensions.cs` — the full biased Unicode/ASCII character generator set (homoglyphs, RTL,
  normalization hazards, wide/fullwidth chars, smart whitespace).
- `GenCustom.cs` — phone-number generators and `GenStringTrimmed` (guarantees no leading/trailing
  whitespace while still allowing it in the middle).
- `GenDateExtensions.cs` — date/time/period generators (future/past dates, same-day and multi-day periods,
  nullable variants).

Install the file(s) through `scripts/Sync-CrowTestingTemplate.ps1` so the namespace adaptation and content
fingerprint are recorded in `docs/testing/testing-plan.md`. Load
[`managed-template-lifecycle.md`](managed-template-lifecycle.md) for the commands and update behavior.
Do not copy these files without registering them: an unregistered copy cannot be distinguished later from
an unrelated or locally customized file when the bundled template changes.
