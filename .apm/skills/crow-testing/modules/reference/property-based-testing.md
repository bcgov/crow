# Property-based testing patterns (CsCheck)

Deeper guidance for writing property-based tests with CsCheck. Load only when actually authoring one.

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
    Gen.String[1, 200].Sample(input =>
    {
        var result = Sanitize.DownloadFileName(input);
        if (!string.IsNullOrEmpty(result))
            Assert.NotEqual('-', result[^1]);
    }, iter: 50, seed: "ValidWithinLimits");
}

[Fact]
public void SanitizedName_OnlyContainsValidSlugCharacters()
{
    Gen.String[1, 200].Sample(input =>
    {
        var result = Sanitize.DownloadFileName(input);
        Assert.Matches(@"^[a-z0-9-]*$", result);
    }, iter: 50, seed: "ValidWithinLimits");
}
```

- Compose generators (`Gen.Int`, `Gen.String`, `Gen.OneOf`, `Gen.Select`, `Gen.Frequency`) to build realistic
  domain objects instead of hand-rolling random values.
- Use a fixed seed for reproducibility in CI; CsCheck reports the failing seed and shrinks to a minimal
  failing case automatically — always include the reported seed when documenting a discovered failure so it
  can be reproduced exactly.
- Keep the property itself simple and obviously correct — a complicated property is as hard to trust as the
  code it's testing.
- Pair a small number of property-based tests (covering the general rule) with a handful of example-based
  tests (covering specific, named edge cases a reader will recognize).

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

Copy the file(s) you need into the project's test-utilities namespace and rename the placeholder
`YourProject.Tests.Generators` namespace to match.
