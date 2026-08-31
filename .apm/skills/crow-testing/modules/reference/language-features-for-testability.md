# Language and runtime features that improve testability

Load when reviewing an existing codebase for testability findings and the project's target framework is
recent enough that newer language or BCL features are available. Produces non-blocking findings for
`docs/testing/testability-notes.md`, in the shape described in
[`testability-improvements.md`](testability-improvements.md).

## First: what tooling already covers

**SonarQube and the built-in Roslyn analyzers run on these projects anyway. Do not spend effort re-deriving
what they already report.** Anything with a rule ID is already on a dashboard, with a severity and a link.

| Already reported by tooling | Rule |
|---|---|
| `new Regex(pattern)` that could be source-generated | `SYSLIB1045` |
| Hand-written null/range guard clauses | `CA1510`–`CA1513` |
| Constructor boilerplate that could be a primary constructor | `IDE0290` |
| Settable collection properties / exposed `List<T>` | `CA2227`, `CA1002`, `S2386`, `S4004` |
| Value type without structural equality | `CA1815`, `S3898` |
| God methods, long methods, high complexity | `S1200`, `S3776`, `S138` |
| Too many parameters | `S107` |
| Publicly visible mutable static state | `S2223`, `S2696` |

The rule to follow:

- **Never run a dedicated hunt for these.** Zero information gained.
- **Do mention one if you land on it** while reading code to write a test. It costs nothing at that point,
  and the rule ID makes it trivially justifiable.

Everything below is in this file precisely because **no analyzer will ever suggest it** — these are design
migrations, not rule violations.

## Second: check what the project can actually use

Proposing a C# 14 feature to a `net472` project is noise, and it costs credibility on the findings that do
apply. Before recommending anything, read:

- `<TargetFramework>` / `<TargetFrameworks>` in the `.csproj` — **with multi-targeting, the lowest TFM
  governs** unless the code is already `#if`-conditioned.
- `<LangVersion>` — often pinned below the default by policy.
- `Directory.Build.props` — where both are frequently set for the whole solution.

## The opportunities no analyzer reports

| Current shape | Move to | Available from | Defect class it removes |
|---|---|---|---|
| `DateTime.Now` / `UtcNow` read inline inside logic | `TimeProvider`, faked with `FakeTimeProvider` | .NET 8 — **backported to `netstandard2.0` / `net462`+ via `Microsoft.Bcl.TimeProvider`** | Midnight rollover, month/year boundaries, leap years, timeouts — currently untestable at *any* filter |
| Nullable property that is really mandatory | `required` members | C# 11 / .NET 7 | "Forgot to set it" ships; the null checks and their tests disappear |
| Raw `int` / `Guid` identifiers passed positionally | `record struct` strongly-typed IDs | C# 10 | Transposed arguments (`Move(orderId, customerId)` called the wrong way round) become compile errors |
| A date with no meaningful time modelled as `DateTime` | `DateOnly` / `TimeOnly` | .NET 6 | Stray time components and timezone shifts silently changing which day a value falls on |
| Several nullable/bool fields modelling what is really one of N states | sealed `record` hierarchy + `switch` expression | C# 9 / C# 8 | Invalid field combinations become unconstructible instead of runtime-validated |

**Lead with `TimeProvider`.** It is the fix for the catalog's **"Untestable time/randomness"** entry — the
only smell whose defects reach *production* before anything catches them — and the backport means even a
`net462` codebase can adopt it. In a brownfield engagement it is usually the single highest-value finding
available.

**No native discriminated unions.** C# has none as of C# 14 — the proposal has not shipped. A sealed record
hierarchy plus an exhaustive `switch` expression is an *approximation*, and worth saying so rather than
implying the language feature exists. It gets most of the benefit: the compiler warns (`CS8509`) on an
unhandled case.

## Cheap move or rewrite?

The user's bar is whether existing code can be changed **without significant effort**. Sort by who finds the
call sites:

- **Cheap — the compiler finds every affected site for you.** `required`, strongly-typed IDs, `DateOnly`,
  making a type a `record`. You change the type, build, and work through the errors. Mechanical, and the
  build proves you finished.
- **Not cheap — behavior can shift silently.** Threading `TimeProvider` through a legacy call chain, or
  reshaping a state model. These need characterization tests *first* — see
  [`characterization-tests.md`](characterization-tests.md) — because nothing will tell you if the behavior
  moved. Say so in the finding; a "quick win" that needs a test suite built first isn't one.

## One EditorConfig lever worth recommending

Most `.editorconfig` content is formatting. One line is not:

```
dotnet_diagnostic.CS8509.severity = error
```

Promoting a warning to a build break is what turns "the compiler mentions it" into "the compiler prevents
it" — filter stage zero, at the cost of one line. It applies equally to the Sonar and CA rules listed at the
top of this file, and it is a cheaper recommendation than any refactor here.

## When the framework forbids it

Some of these are genuinely unavailable, and pushing anyway wastes the user's goodwill. Real constraints:

- **Two-way data binding** — WinForms, WPF, MAUI, and Blazor `@bind` need publicly settable properties, and
  usually `INotifyPropertyChanged`. `init`-only records don't bind.
- **EF Core entity materialization** — entities need a usable constructor, and navigation collections must
  be mutable for change tracking and lazy loading.
- **Model binding and serializers** — ASP.NET model binding and `System.Text.Json` handle records, but with
  constraints around parameterless construction, `required`, and polymorphism.
- **Generated code** — designer files, source-generated partials, and service proxies aren't yours to
  reshape.
- **A pinned `LangVersion`** — sometimes a build-policy decision, not an oversight.

**The answer is usually a partial move, not a refusal.** The constraint applies at the *framework edge*, not
to the whole codebase: keep the mutable, bindable, materializable type where the framework demands it, put
the immutable record in the domain, and map once at the boundary. That is the same seam extraction the skill
already teaches — see `testability-improvements.md` § seam-extraction playbook — and it moves the rules onto
a type the compiler can defend, while the framework keeps the shape it needs.

Where even the partial move isn't worth it: **surface it, let the user decide, and record the decision** in
the "Accepted constraints and decisions" table of `docs/testing/testability-notes.md`. A constraint is not a
smell, and it should not be re-raised as a finding on every future engagement.
