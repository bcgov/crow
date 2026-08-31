# Test data builders

Deeper guidance on the builder pattern for constructing test subjects. Load when writing or reviewing a
builder. The compact rule in `dotnet/unit-tests.md` — "a builder per model, seeded, defaults valid" — is the
summary; this file is the detail behind it.

## The core contract

**A builder's defaults must produce a fully valid object.** Every test then sets only the one thing it is
actually testing, and any assertion failure points at that one thing rather than at incidental setup. This
contract is load-bearing enough to test directly:

```csharp
[Fact]
public void Builder_DefaultValues_ProduceValidModel()
{
    var model = new UserProfileBuilder().Build();

    Assert.NotNull(model.FirstName);
    Assert.True(model.Email != null || model.PrimaryPhone != null,
        "Builder should provide at least email or phone");

    _validator.TestValidate(model).ShouldNotHaveAnyValidationErrors();
}
```

Without this test, a drifting builder silently invalidates every test that depends on it, and the failures
appear scattered across unrelated test classes.

## Generated defaults, pinned constraints

Generate realistic values rather than hand-writing them, then pin the fields the domain actually constrains:

```csharp
private Faker<UserProfile> CreateFaker(string locale) =>
    new AutoFaker<UserProfile>(locale).UseSeed(_seed)
        .RuleFor(m => m.ProfileId,  f => f.Random.Int(1, 10000))
        .RuleFor(m => m.LastName,   f => f.Name.LastName())
        .RuleFor(m => m.MononymFlg, f => false)
        .RuleFor(m => m.BirthDt,    f => f.Date.Between(
            ValidationConstants.MinDate.AddYears(10),
            ValidationConstants.MaxBirthDate.AddDays(-1)))
        .RuleFor(m => m.PreferredName, f => f.Internet.UserName().OrNull(f, 0.3f))
        .RuleFor(m => m.Address,    f => new AddressModelBuilder().WithLocale(locale).Build());
```

- Derive date/number bounds from the **same constants the production validator uses**, not from copied
  literals — otherwise a changed rule leaves the builder generating invalid data.
- `.OrNull(f, 0.3f)` exercises the nullable path some of the time without making defaults unpredictable.
- Compose nested builders rather than hand-building child objects, so each type's validity rules live in one
  place.

### Naming conventions for auto-generation

Where an auto-faker infers data types from property names, configure the aliases once so domain-specific
names still generate sensible data:

```csharp
static UserProfileBuilder()
{
    AutoFaker.Configure(builder => builder.WithConventions(config =>
    {
        config.PhoneNumber.Aliases("PrimaryPhone", "OtherPhone");
        config.ExampleEmail.Aliases("Email");
        config.FirstName.Aliases("PreferredName");
    }));
}
```

Note this is **static, global, and runs once** — see thread safety below.

## Semantic composite methods, not one setter per property

The most valuable builder methods move the object to a **coherent named state**, setting several fields
together the way the domain requires:

```csharp
public UserProfileBuilder WithSingleName(string firstName)
{
    _model.FirstName  = firstName;
    _model.LastName   = null;        // a mononym has no surname
    _model.MononymFlg = true;
    return this;
}

public UserProfileBuilder WithTranslator(string? language = null)
{
    _model.TranslatorRequired = true;
    _model.Language = language ?? "Other";
    return this;
}
```

A test then reads `new UserProfileBuilder().WithSingleName("Sample").Build()` — the intent is obvious, and
the three-field invariant can't be got wrong in test #7 the way it was got right in test #3. Compare with
three separate `WithFirstName`/`WithLastName`/`WithMononymFlg` calls, which push the domain rule into every
test that touches it.

Provide plain per-property setters too (`WithEmail`, `WithNote`) for tests that genuinely vary one field —
but reach for a named state whenever fields must move together.

### Nested composition

Let a builder accept either a finished child object or a configuration callback:

```csharp
public UserProfileBuilder WithAddress(AddressModel address) { _model.Address = address; return this; }

public UserProfileBuilder WithAddressBuilder(Action<AddressModelBuilder> configure)
{
    var builder = new AddressModelBuilder();
    configure(builder);
    _model.Address = builder.Build();
    return this;
}
```

The callback form keeps tests from importing and assembling child builders inline for a one-field change.

## Determinism and seeds

- **Fix the seed** (`UseSeed(_seed)`) so a failure reproduces exactly. Randomized-per-run defaults produce
  tests that fail once and pass on retry, which trains everyone to ignore failures.
- Keep the seed a named constant on the builder, not scattered literals.
- Determinism here is separate from property-based testing's seeds — see
  [`property-based-testing.md`](property-based-testing.md) for the named-seed convention used there.

## Localization

A `WithLocale()` method regenerating locale-sensitive fields is worth having when the system accepts
international input — it turns "does this validator cope with non-English names, addresses, and phone
formats?" into a one-line test:

```csharp
foreach (var locale in new[] { "en_CA", "de", "fr", "ja" })
{
    var model = new UserProfileBuilder().WithLocale(locale).Build();
    _validator.TestValidate(model).ShouldNotHaveAnyValidationErrors();
}
```

Regenerate only the fields the locale actually affects (names, phone, address) and leave the rest pinned, so
locale tests don't accidentally vary unrelated data.

## Thread safety

Test runners execute test classes in parallel by default. Two consequences:

- **Static/global configuration must be idempotent and set up once.** A static constructor is a reasonable
  home for it (the runtime guarantees single execution), but a global registry mutated *per builder instance*
  will race. Never let `Build()` mutate global state.
- **Never share a built model between tests.** Each test constructs its own via the builder. A builder
  instance holding a single `_model` it hands out (`Build() => _model`) is fine only because each test creates
  its own builder — if a builder instance is ever cached or shared in a fixture, `Build()` must return a fresh
  copy instead.
- If the object graph is genuinely expensive to generate and you cache it in a shared fixture, return an
  immutable snapshot or a deep copy; otherwise one test's mutation corrupts another's arrangement. See the
  "Mutable state by default" entry in [`design-smell-entries.md`](design-smell-entries.md).

## Where builders live

Keep them in a dedicated `Builders/` folder, one file per model, named `{Model}Builder.cs` — see the layout
section in [`../dotnet/unit-tests.md`](../dotnet/unit-tests.md).
