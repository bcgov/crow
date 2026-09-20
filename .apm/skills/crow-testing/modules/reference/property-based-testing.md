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

```csharp
[Fact]
public void SanitizedName_NeverEndsWithDash()
{
    Gen.String[1, 200].SampleProperty(input =>
    {
        var result = Sanitize.DownloadFileName(input);
        if (!string.IsNullOrEmpty(result))
            Assert.NotEqual('-', result[^1]);
    }, seed: "ValidWithinLimits");
}

[Fact]
public void SanitizedName_OnlyContainsValidSlugCharacters()
{
    Gen.String[1, 200].SampleProperty(input =>
    {
        var result = Sanitize.DownloadFileName(input);
        Assert.Matches(@"^[a-z0-9-]*$", result);
    }, seed: "ValidWithinLimits");
}
```

- Compose generators (`Gen.Int`, `Gen.String`, `Gen.OneOf`, `Gen.Select`, `Gen.Frequency`) to build realistic
  domain objects instead of hand-rolling random values.
- Use the shared `PropertyTestSampling` helper from the managed Crow template (install it the same way as
  the generator files below — see "Don't just adapt this" further down this page). Normal CI/CD and local
  runs use reproducible per-iteration seeds derived from the supplied descriptive seed, so failures reproduce
  exactly even though CsCheck applies its `seed` argument only to the first iteration of a multi-iteration
  sample. Set `CsCheck_Randomize=true` for an exploratory run that uses CsCheck's default random seeding
  without changing every test.
- For example, opt into exploration for one PowerShell run with
  `$env:CsCheck_Randomize = "true"; dotnet test`. Keep the test process's standard output and error in the
  run log so CsCheck's reproduction seed is not lost.
- A fixed seed gives repeatability, not broad exploration. Make each iteration valuable by shaping generators
  toward the domain's real partitions and known hazards: valid and invalid forms, duplicate values,
  cross-field dependencies, Unicode/normalization hazards, and boundary-adjacent values. Add explicit
  examples for named edge cases; do not expect more iterations from an unshaped generator to compensate for
  poor input coverage.
- When random mode finds a failure, capture CsCheck's reported reproduction seed and minimized input, then
  rerun deterministically with that seed. Fix the defect and promote the minimized input to a permanent
  regression example or property seed when it represents a durable defect class.
- Keep the property itself simple and obviously correct — a complicated property is as hard to trust as the
  code it's testing.
- Pair a small number of property-based tests (covering the general rule) with a handful of example-based
  tests (covering specific, named edge cases a reader will recognize).

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
    Gen.String[Gen.Char.AlphaNumeric, 210, 260].SampleProperty(local =>
    {
        var model = BuildModelWithEmail(local + "@test.com");
        Validator.TestValidate(model).ShouldHaveValidationErrorFor(EmailExpression);
    }, iter: 20, seed: "EmailTooLong");
}
```

## Iteration counts and seed naming

- **Iterations:** use **100** for cross-field and property exploration where combinations matter, such as
  duplicate names, contact interdependencies, and Unicode/normalization rules. Keep explicit boundary
  properties at **20** when the generator already targets a narrow condition, such as values just beyond a
  known maximum. The generator's bias and partition coverage matter more than raw volume; raise counts only
  when the state space and runtime justify it.
- **Seeds:** give every `SampleProperty` call an explicit, descriptive seed naming what's being generated
  (`seed: "EmailTooLong"`, `seed: "ValidWithinLimits"`). This keeps runs reproducible, makes a failing test's
  intent readable without parsing the generator, and avoids two unrelated tests sharing an accidental seed.
  The shared helper lets an exploratory run ignore those seeds without changing test code. When a property
  discovers a real bug, record the reported failing seed during replay and promote the minimized input into
  the fix's test so the exact case stays covered.

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

**Don't just adapt this — copy the real, already-tested files.** `templates/dotnet/generators/` has four
ready-to-use generator/helper utilities, tried and proven, that save you from regenerating (and
re-introducing mistakes into) this kind of code from scratch:

- `GenCharExtensions.cs` — the full biased Unicode/ASCII character generator set (homoglyphs, RTL,
  normalization hazards, wide/fullwidth chars, smart whitespace).
- `GenCustom.cs` — phone-number generators and `GenStringTrimmed` (guarantees no leading/trailing
  whitespace while still allowing it in the middle).
- `GenDateExtensions.cs` — date/time/period generators (future/past dates, same-day and multi-day periods,
  nullable variants).
- `PropertyTestSampling.cs` — the `SampleProperty` execution helper described above (deterministic-by-default
  sampling, the `CsCheck_Randomize` exploratory-run switch).

Install the file(s) through `scripts/Sync-CrowTestingTemplate.ps1` so the namespace adaptation and both
content fingerprints are recorded in `docs/testing/testing-plan.md`. Load
[`managed-template-lifecycle.md`](managed-template-lifecycle.md) for the commands and update behavior.
Do not copy these files without registering them: an unregistered copy cannot be distinguished later from
an unrelated or locally customized file when the bundled template changes.
