# .NET `.editorconfig` and analyzer baseline

Load when a .NET repository has no `.editorconfig`, when a testing or review engagement reports missing
analyzer configuration, or when creating a new .NET solution. Analyzer feedback only helps if the build
reports it, so the baseline is what lets generated application and test code be checked at build time.

## Detect first, never overwrite

1. Search from the repository root and each solution/project directory upward for `.editorconfig`,
   `Directory.Build.props`, `Directory.Build.targets`, and `*.globalconfig`. An `.editorconfig` with
   `root = true` at the repository root is the existing convention.
2. If one exists, **do not replace or reformat it.** Compare against the baseline below and propose only
   additions the user approves. Keep the file's existing indentation, line-ending, and naming choices.
3. If none exists, create a repository-root `.editorconfig` from the baseline, adjusted to what the
   repository already does (indent style/size, `end_of_line`, file-scoped namespaces). Infer these from
   several existing source files rather than assuming. Tell the user the file was added and why.
4. Check line endings against `.gitattributes`/`core.autocrlf` before setting `end_of_line`; a mismatch
   produces whole-file diffs.

## Baseline `.editorconfig`

Formatting is stylistic and project-specific; the part that matters is analyzer severity.

```ini
root = true

[*]
charset = utf-8
insert_final_newline = true
trim_trailing_whitespace = true

[*.{cs,razor}]
indent_style = space
indent_size = 4
# end_of_line: match .gitattributes / existing files before setting

[*.cs]
# Naming and style: keep the repository's existing choices; add only what is already followed.
csharp_style_namespace_declarations = file_scoped:suggestion

# Correctness rules worth failing the build on in new code.
# EditorConfig has no inline comments; keep every comment on its own line.
# CA1816: call GC.SuppressFinalize correctly
dotnet_diagnostic.CA1816.severity = warning
# CA1822: mark members as static
dotnet_diagnostic.CA1822.severity = warning
# CA1869: cache and reuse JsonSerializerOptions
dotnet_diagnostic.CA1869.severity = warning
# CS8509: non-exhaustive switch expression
dotnet_diagnostic.CS8509.severity = error

# Noisy rules with low value; set explicitly rather than leaving a recurring warning.
# CA1873: avoid potentially expensive logging (noise on guarded logs)
# dotnet_diagnostic.CA1873.severity = none

[*.{csproj,props,targets}]
indent_size = 2

# Tests: relax only rules that conflict with the test idiom, and say why.
# Prefer placing these in tests/.editorconfig so production code keeps the strict setting.
# [**/*Tests*/**.cs]
# CA1707: underscores in test method names
# dotnet_diagnostic.CA1707.severity = none
```

Do not bulk-disable analyzers to silence an existing backlog. Set a rule to `none` only when it is
demonstrably noise for this repository and record the reason in a comment. Never silence a
security diagnostic.

## Project switches

Make analyzers run at build time (these default to off or to the IDE only):

```xml
<PropertyGroup>
  <Nullable>enable</Nullable>
  <EnforceCodeStyleInBuild>true</EnforceCodeStyleInBuild>
  <AnalysisLevel>latest-recommended</AnalysisLevel>
</PropertyGroup>
```

- Put shared properties in `Directory.Build.props` when the solution has several projects, rather than
  repeating them.
- Do **not** add `TreatWarningsAsErrors` to an existing project with a warning backlog; that fails the
  build for unrelated code. For a new project it is reasonable. For an existing one, use
  `-warnaserror:<rule>` in CI on specific rules, or a ratchet agreed with the team.
- xUnit analyzers: xUnit v3 test projects include `xunit.analyzers`, and the v2 `xunit` metapackage already
  references it transitively. Check for an existing reference before adding one. Rules are version-specific:
  xUnit1051 (and `Assert.Skip`) apply to v3 only, so on a retained v2 suite list only v2-supported rules
  such as xUnit1004 and xUnit1045.
- Sonar rules (`S*`) run through the Sonar scanner or the `SonarAnalyzer.CSharp` package. SonarQube's C#
  documentation supports file-scoped `dotnet_diagnostic.Sxxxx.severity = none` in `.editorconfig` as well as
  `CA*` rules, so try that before changing server configuration. If the issue still appears in a scan, the
  server-side quality profile or an ignore rule is the fallback. The suppression restrictions above still
  apply, and confirm the effect with a scan.

## Verification

Build the solution after adding the file. Report the count of newly surfaced warnings by rule; do not fix
or suppress them in the same change unless asked. Run the existing formatter check if one is configured
(`dotnet format --verify-no-changes`) to confirm the new file did not reformat unrelated code.

## Sources

- Microsoft Learn, [Configuration files for code analysis rules](https://learn.microsoft.com/dotnet/fundamentals/code-analysis/configuration-files)
- Microsoft Learn, [Code-analysis overview and `AnalysisLevel`](https://learn.microsoft.com/dotnet/fundamentals/code-analysis/overview)
- Microsoft Learn, [`EnforceCodeStyleInBuild`](https://learn.microsoft.com/dotnet/core/project-sdk/msbuild-props#enforcecodestyleinbuild)
- xunit.analyzers, [rule index](https://xunit.net/xunit.analyzers/rules/)
