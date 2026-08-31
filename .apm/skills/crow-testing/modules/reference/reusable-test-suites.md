# Reusable abstract test suites

Deeper guidance for the highest-leverage structural pattern in a validation-heavy test project. Load when
the same *field type* (email, phone, address, name) or the same *behavior contract* appears on more than one
model and you'd otherwise copy a test file per model.

## The problem it solves

Five models each with an email, phone, address, and name field means twenty test files, each independently
maintained. Adding one new email edge case means editing five files, and drift is guaranteed — one model
quietly stops covering a case the others do. Coverage becomes a function of who remembered to copy.

## The shape

Put the tests **once** in an abstract generic base class, parameterized by the model and its validator. Each
concrete per-model class supplies only the wiring: how to build a model with a given value, and which
property the assertion should target.

```csharp
public abstract class EmailValidationTestSuite<TModel, TValidator>
    where TValidator : IValidator<TModel>, new()
{
    protected readonly TValidator Validator = new();
    protected readonly ITestOutputHelper Output;

    protected EmailValidationTestSuite(ITestOutputHelper output) => Output = output;

    // Wiring the concrete class must supply:
    protected abstract TModel BuildModelWithEmail(string? email);
    protected abstract Expression<Func<TModel, string?>> EmailExpression { get; }
    protected abstract string? GetEmail(TModel model);   // for diagnostic output only

    [Theory]
    [InlineData("simple@example.com")]
    [InlineData("user+tag@example.com")]
    public void ValidEmailFormats_ShouldPass(string email)
    {
        var model = BuildModelWithEmail(email);
        var result = Validator.TestValidate(model);

        Output.WriteLine($"Testing valid email: {email}");
        result.ShouldNotHaveValidationErrorFor(EmailExpression);
    }

    // ... invalid formats, length boundaries, property-based coverage — written once
}
```

The concrete class then contains **no assertions at all** — only implementations of the abstract members:

```csharp
public class UserProfileAddressFieldsTests
    : AddressValidationTestSuite<UserProfile, UserProfileValidator>
{
    public UserProfileAddressFieldsTests(ITestOutputHelper output) : base(output) { }

    protected override UserProfile BuildModelWithAddress(AddressModel address)
        => new UserProfileBuilder().WithAddress(address).Build();

    protected override Expression<Func<UserProfile, string?>> CityExpression
        => x => x.Address.City;

    protected override AddressModel GetAddress(UserProfile model) => model.Address;
}
```

Real per-model files written this way run to roughly 40 lines. The test runner still discovers and reports
them per concrete class, so a failure names the model it actually failed on.

## Why expressions rather than property names

`Expression<Func<TModel, string?>>` keeps the wiring **type-safe and refactor-safe**: renaming the property
updates the expression, and a wrong property name fails to compile. String-based property paths silently rot.
Expressions also handle nested properties naturally (`x => x.Address.City`).

## When it pays off

- The same field type/contract appears on **three or more** models. At two, it's usually a coin flip; below
  that, abstraction costs more than it saves.
- The rules for that field are genuinely intended to be **identical** across models. If they legitimately
  differ per model, a shared suite forces false uniformity.
- You expect the rule set to keep growing. The suite is where a new edge case gets added once and instantly
  applies everywhere.

## When *not* to abstract

- **Model-specific fields.** Fields unique to one model (a worker's deceased flag, an inquiry's file number)
  belong in a plain `{Entity}PersonalInfoFieldsTests.cs`, not forced into a suite with a single implementer.
- **Cross-field rules.** Interdependencies between fields are model-specific by nature — keep them in
  `CrossField/` (see `dotnet/unit-tests.md`'s layout section), not in a per-field suite.
- **When "shared" is aspirational.** If two models' email rules differ today and you abstract anyway, you end
  up with virtual hooks and opt-out flags — worse than two honest files. Abstract the parts that are truly
  common, or don't.
- **Deep inheritance.** One abstract suite, one concrete class. If you find yourself with a suite inheriting
  a suite, the shared behavior wants to be a helper or a shared theory-data source instead.

## Practical notes

- Keep the abstract members minimal: a builder method, the property expression(s), and a getter used only for
  diagnostic output. The more the concrete class must supply, the less the suite is actually saving.
- Constrain the validator generically (`where TValidator : IValidator<TModel>, new()`) so the suite can
  construct it itself and the concrete class doesn't repeat that boilerplate.
- Pass `ITestOutputHelper` down through the base constructor — the suite's own diagnostics need it, and every
  concrete class gets it for free.
- The same pattern generalizes beyond validation: any contract that several types must satisfy (a repository
  interface, a serializer round-trip, an `IEquatable<T>` implementation) can be tested once in an abstract
  suite and wired per implementation.
