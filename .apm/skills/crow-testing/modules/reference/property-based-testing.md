# Property-based testing patterns (CsCheck)

Deeper guidance for writing property-based tests with CsCheck. Load only when actually authoring one.

## When to reach for a property-based test

Use it for validation rules and invariants that must hold across a wide range of inputs (e.g. "any string
longer than N characters fails validation", "round-tripping through the mapper never loses a required
field") — not for a single fixed example, which a normal example-based test covers better.

## Core pattern

```csharp
Gen.String[0, 50].Sample(value =>
{
    var result = validator.Validate(new Model { Field = value });
    (value.Length <= 50).Should().Be(result.IsValid);
});
```

- Compose generators (`Gen.Int`, `Gen.String`, `Gen.OneOf`, `Gen.Select`) to build realistic domain objects
  instead of hand-rolling random values.
- Use a fixed seed for reproducibility in CI; CsCheck reports the failing seed and shrinks to a minimal
  failing case automatically — always include the reported seed when documenting a discovered failure so it
  can be reproduced exactly.
- Keep the property itself simple and obviously correct — a complicated property is as hard to trust as the
  code it's testing.
- Pair a small number of property-based tests (covering the general rule) with a handful of example-based
  tests (covering specific, named edge cases a reader will recognize).
