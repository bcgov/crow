# Property-based testing patterns (CsCheck)

Deeper guidance for writing property-based tests with CsCheck. Load only when actually authoring one.

**Prerequisites:** use the project's existing property-testing library when one is established. Add the
`CsCheck` NuGet package only when no meaningful convention exists and the user accepts the dependency.

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
    var email = new string('a', 184) + "@example.invalid";
    Assert.Equal(200, email.Length);
    Validator.TestValidate(BuildModelWithEmail(email))
             .ShouldNotHaveValidationErrorFor(EmailExpression);
}

[Fact]
public void Property_Email_Exceeding_200_Chars_Always_Fails()   // the space beyond it
{
    Gen.String[Gen.Char.AlphaNumeric, 210, 260].Sample(local =>
    {
        var model = BuildModelWithEmail(local + "@example.invalid");
        Validator.TestValidate(model).ShouldHaveValidationErrorFor(EmailExpression);
    }, iter: 10, seed: "EmailTooLong");
}
```

## Iteration counts and seed naming

- **Iterations:** 10-20 is usually right for validation rules. The generator's *bias* matters far more than
  raw volume — a well-shaped generator finds the bug in 10 iterations, while a uniform one may not find it in
  10,000. Raise the count only for genuinely large state spaces, and watch the effect on suite runtime; slow
  tests get skipped, which costs more coverage than the extra iterations bought.
- **Seeds:** give every `Sample` call an explicit, descriptive seed naming what's being generated
  (`seed: "EmailTooLong"`, `seed: "ValidWithinLimits"`). This keeps runs reproducible, makes a failing test's
  intent readable without parsing the generator, and avoids two unrelated tests sharing an accidental seed.
  When a property discovers a real bug, record the reported failing seed in the fix's test so the exact case
  stays covered.

## Biased character generators (for string/format validation)

A uniform-random `Gen.String` under-samples the edge cases that cause bugs. Build a project-specific generator
that heavily samples accepted common input while deliberately including small sets for normalization,
homoglyph, right-to-left, full-width, and unusual-whitespace cases relevant to the field. Keep the weights and
character sets visible so reviewers can verify the distribution.

Build the smallest project-specific generator that expresses the accepted domain constraints. Keep copied
third-party or internal-project utilities out of generated tests unless their licence and attribution permit
reuse. Verify generator APIs against the version already referenced by the target project instead of assuming
the example above is source-compatible.
