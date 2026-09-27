# Property-based testing patterns (CsCheck)

Deeper guidance for writing property-based tests with CsCheck. Load only when actually authoring one.

**Prerequisites:** add the `CsCheck` NuGet package to the test project. The generator templates below
target a modern .NET TFM; if the project targets .NET 5 or earlier, drop or replace any `TimeOnly`/`DateOnly`
generators in `GenDateExtensions.cs` (introduced in .NET 6) with `DateTime`-based equivalents.

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

Call `Sample` directly from CsCheck — no wrapper. Omit `seed:` for normal exploration; the
[seed section](#what-seed-does-and-does-not-do) below explains why.

```csharp
[Fact]
public void SanitizedName_NeverEndsWithDash()
{
    Gen.String[1, 200].Sample(input =>
    {
        var result = Sanitize.DownloadFileName(input);
        if (!string.IsNullOrEmpty(result))
            Assert.NotEqual('-', result[^1]);
    });
}

[Fact]
public void SanitizedName_OnlyContainsValidSlugCharacters()
{
    Gen.String[1, 200].Sample(input =>
    {
        var result = Sanitize.DownloadFileName(input);
        Assert.Matches(@"^[a-z0-9-]*$", result);
    });
}
```

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

## What `seed:` does (and does not) do

CsCheck's `seed:` argument and `CsCheck_Seed` environment variable are commonly misread as a
"deterministic CI/CD" switch. They are not.

> **Common pitfalls**
>
> - A seeded **Bogus builder** fixes fixture defaults for the same builder, locale, seed, and generation
>   sequence; it is not the same mechanism as CsCheck exploration.
> - CsCheck properties are **unseeded by default**. Its `seed:` pins the first iteration only, not the
>   whole test run.
> - Replay a reported seed only for a pinned regression (normally with `iter: 1`); keep the general
>   property unseeded so exploration continues. See the detailed seed policy below.

**What `Sample(assertion, seed: X, iter: N)` actually does** (revalidate against the CsCheck version used
by the target project when upgrading the dependency):

- Iteration 1 is generated from the parsed PCG state of `X`.
- Iterations 2..N run across worker threads (default = `Environment.ProcessorCount`), each seeded from
  `Stopwatch.GetTimestamp()` on first touch of its thread-static PCG.
- Therefore a supplied seed pins **one case only**, not the whole run. Iterations 2..N still vary across
  runs and thread scheduling.

**Reproducibility of failures does not come from pinning the run.** It comes from the CsCheck shrinker,
which prints the seed of the *minimal failing case* on failure. The developer replays that seed for
investigation and promotes the minimized input into a permanent regression test. See
[Regression pattern for a discovered failure](#regression-pattern-for-a-discovered-failure).

**Conventions:**

- **Omit `seed:` by default.** Let CsCheck use its default seeding so every run explores different inputs.
  This is what compounds coverage over time across the team's CI runs.
- **Pass `seed:` only** when re-covering a specific reported failure as a regression (paired with `iter: 1`
  so no unrelated case can also fail from that call), or when a test is deliberately documenting a "canary"
  case for iteration 1. A descriptive seed is not documentation of test intent; put the intent in the test
  name and generator composition.

This is a different determinism model than test-data builders. Bogus builders should still use a
fixed seed so a fixture's defaults reproduce exactly; that's a separate concern from CsCheck's exploration.

## Iteration counts

- **General property tests:** omit `iter:` and inherit CsCheck's static default (`Check.Iter = 100`). See
  [Two-build strategy](#two-build-strategy-pr-run-vs-nightly-run) for how the nightly run scales this.
- **Narrow, already-biased property spaces** (for example, varied invalid email forms just beyond a length
  threshold — generator space itself is small and targeted): pass `iter: 20`. An explicit `iter:` value does
  not scale with the nightly env var, which is the desired behavior — a narrow space does not benefit from
  more iterations.
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
    Gen.String[Gen.Char.AlphaNumeric, 210, 260].Sample(local =>
    {
        var model = BuildModelWithEmail(local + "@test.com");
        Validator.TestValidate(model).ShouldHaveValidationErrorFor(EmailExpression);
    }, iter: 20);
}
```

## Two-build strategy: PR run vs nightly run

Property-based tests belong in CI — dev-only exploration wastes their value. The standard shape is two
pipelines that share the same tests but exercise them differently.

- **PR / main pipeline:** run with CsCheck's default `Check.Iter = 100`. Fast feedback, catches obvious
  regressions and any new property violation. Any failure is reproducible from the reported seed.
- **Nightly pipeline:** set the `CsCheck_Iter` environment variable to scale general property tests
  (typical value: `1000`). Explicit `iter:` values on narrow boundary properties intentionally do not
  scale — their generator space is small. Deeper exploration compounds coverage across nights.

Both pipelines rely on the same failure workflow: shrinker prints the reproducing seed → developer pins
the minimized input as a regression test → next runs keep exploring. Determinism of the whole run is
neither required nor useful; determinism of *each discovered failure* is guaranteed by the shrinker's
reported seed.

### Running the test project with a larger iteration count

The nightly job (or an ad-hoc local exploratory run) sets `CsCheck_Iter` before invoking `dotnet test`.
The env var only scales tests that did not pass an explicit `iter:` argument, so boundary-property tests
stay at their pinned counts by design.

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
validation properties, prefer `CsCheck_Iter`.

```bash
CsCheck_Time=5 dotnet test   # per property, NOT per suite
```

## Regression pattern for a discovered failure

When a property-based run fails, CsCheck prints a line like:

```
Set seed: "0000018ab..." or -e CsCheck_Seed=0000018ab... to reproduce (12 shrinks, 3,456 skipped, 4,000 total).
```

Two ways to turn that into a durable regression:

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
      Gen.String[1, 200].Sample(local =>
      {
          var model = BuildModelWithEmail(local);
          Validator.TestValidate(model).ShouldHaveValidationErrorFor(EmailExpression);
      }, seed: "0000018ab...", iter: 1);
  }
  ```

Either way, keep the unseeded general property alongside the pinned regression so exploration continues.

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
