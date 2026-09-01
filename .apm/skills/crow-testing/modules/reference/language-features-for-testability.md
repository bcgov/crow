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

## Second: what the project *can* use

Proposing a C# 14 feature to a `net472` project is noise, and it costs credibility on the findings that do
apply. Before recommending anything, read:

- `<TargetFramework>` / `<TargetFrameworks>` in the `.csproj` — **with multi-targeting, the lowest TFM
  governs** unless the code is already `#if`-conditioned.
- `<LangVersion>` — often pinned below the default by policy.
- `Directory.Build.props` — where both are frequently set for the whole solution.

## Third: what the project *actually* uses

That check is one-way. The more common case in a maintained codebase is the reverse: **the framework allows
it and the code doesn't use it.**

Retargeting rewrites nothing. A team that moved from `net472` to `net8.0` will say "we're on .NET 8" —
meaning the runtime — while new files still get `DateTime.Now`, an `int?` plus a null check, and a `switch`
statement with a `default` arm, because that's what the file next to them looks like. **A modern target
framework is not modern code**, and the gap between them is where these findings live.

### Signals, strongest first

| Signal | What it tells you |
|---|---|
| `.editorconfig` declares a modern preference the code violates | **Strongest.** The argument is already settled — nothing is enforcing it. See § EditorConfig below |
| `.editorconfig` explicitly pins the *older* style | **Stop.** That's a deliberate decision; don't re-litigate it as a finding |
| The modern idiom already appears *somewhere* in the solution | The team can and does write it, so its absence elsewhere is drift, not a capability gap |
| Both idioms inside one file or folder | Drift is happening *now*, not historically — the strongest case for a convention decision |
| `<Nullable>`, `<ImplicitUsings>`, SDK-style `.csproj`, `Directory.Build.props` | What the build already assumes about modernity |
| File-scoped vs block-scoped namespaces, top-level statements, whether nullable annotations appear at all | Roughly when a file was written or last reworked — **needs no version control** |
| `git log` / `git log -S "DateTime.Now"` on the area | Useful **when available** — distinguishes a live habit from priced-in legacy |
| Filesystem timestamps | Ignore. A fresh clone resets them |

Don't depend on version control. History is often shallow-cloned, squashed, or lost in a migration between
systems, and recency only tells you *when* something was written — never whether the team considers it
correct. The declaration-based signals above are both more available and more authoritative.

**When the signals are weak or conflict, ask.** The user knows which areas are under active development and
which are frozen, and that answer outranks anything inferred from the files.

### Why it changes the finding

Old code in an old idiom is legacy — the cost is already paid and priced in. **New code in an old idiom is a
live habit**, and it keeps producing more of the same until someone names it. Same line of code, different
finding:

> not *"this code is dated"* but *"this is what we are still writing."*

## The opportunities no analyzer reports

| Current shape | Move to | Available from | Defect class it removes |
|---|---|---|---|
| `<Nullable>` unset or `disable` on a modern TFM | `<Nullable>enable</Nullable>` | C# 8 / .NET Core 3.0 | **Every** null defect the compiler could have caught — filter stage zero is switched off solution-wide |
| `DateTime.Now` / `UtcNow` read inline inside logic | `TimeProvider`, faked with `FakeTimeProvider` | .NET 8 — **backported to `netstandard2.0` / `net462`+ via `Microsoft.Bcl.TimeProvider`** | Midnight rollover, month/year boundaries, leap years, timeouts — currently untestable at *any* filter |
| Nullable property that is really mandatory | `required` members | C# 11 / .NET 7 | "Forgot to set it" ships; the null checks and their tests disappear |
| Raw `int` / `Guid` identifiers passed positionally | `record struct` strongly-typed IDs | C# 10 | Transposed arguments (`Move(orderId, customerId)` called the wrong way round) become compile errors |
| A date with no meaningful time modelled as `DateTime` | `DateOnly` / `TimeOnly` | .NET 6 | Stray time components and timezone shifts silently changing which day a value falls on |
| Several nullable/bool fields modelling what is really one of N states | sealed `record` hierarchy + `switch` expression | C# 9 / C# 8 | Invalid field combinations become unconstructible instead of runtime-validated |

**Check `<Nullable>` first — it is the cheapest and widest of these.** It defaults to `disable` when
unspecified, and retargeting never adds it, so a solution can sit on `net8.0` for years with the compiler's
null analysis simply not running. Nothing reports this; it is an absence, not a violation. Adopt it
incrementally rather than all at once: turn it on solution-wide with the warnings non-fatal and burn them
down, or enable per file with `#nullable enable` on new and touched files (which is the stop-the-bleeding
approach below).

**Then `TimeProvider`.** It is the fix for the catalog's **"Untestable time/randomness"** entry — the only
smell whose defects reach *production* before anything catches them — and the backport puts it within reach
of even a `net462` codebase.

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

### Usually the answer is neither: stop the bleeding first

Converting an existing codebase wholesale fails
[`testability-improvements.md`](testability-improvements.md)'s own bar — the change must remove more test
surface than it adds, and a solution-wide modernization pass doesn't. So don't propose one.

Propose the convention instead: **new code uses the current idiom; existing code converts when it's being
touched anyway.** It requires no refactor, carries no regression risk, and is worth more over time than
converting any number of existing files, because it caps the pile rather than shrinking it.

This turns a refactor proposal — expensive, easy to decline, easy to defer forever — into a **convention
decision**, which is a much easier yes and, unlike a refactor, can be enforced mechanically rather than by
reviewer vigilance.

## Making it stick: EditorConfig and the two gates

Most `.editorconfig` content is formatting. The part that isn't is where this whole file lands, and it comes
with a trap worth knowing.

**Both enforcement gates default to off:**

1. `<EnforceCodeStyleInBuild>` defaults to **`false`** — so `IDExxxx` code-style rules are reported in the
   IDE only, never at build or in CI.
2. Even with it set to `true`, a rule only breaks the build at severity **`error`** (or `warning` with
   `<TreatWarningsAsErrors>`). The defaults, `suggestion` and `silent`, fail nothing.

So a project can declare `csharp_style_prefer_switch_expression`,
`csharp_style_prefer_primary_constructors`, `dotnet_style_readonly_field` and the rest — and drift from all
of them indefinitely, because the only consequence is a grey squiggle in one editor that nobody is obliged
to look at.

That makes it the **easiest recommendation in this file to get accepted**, because it isn't really a
proposal:

> You're not asking them to adopt a standard. They already agreed this one. It just has no teeth.

```xml
<PropertyGroup>
  <EnforceCodeStyleInBuild>true</EnforceCodeStyleInBuild>
  <Nullable>enable</Nullable>
  <TreatWarningsAsErrors>true</TreatWarningsAsErrors>
</PropertyGroup>
```
```ini
dotnet_diagnostic.CS8509.severity = error
```

Promoting a warning to a build break is what turns "the compiler mentions it" into "the compiler prevents
it" — filter stage zero, at the cost of a few lines and no application code at all. It applies equally to
the Sonar and CA rules listed at the top of this file, and it is a cheaper recommendation than any refactor
here.

Introduce it the same way as `<Nullable>`: turn enforcement on, and if the existing violation count is too
large to fix at once, raise severity on the rules that matter first rather than abandoning the idea.

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
