---
name: crow-sonar-scan
description: Triggers when the user asks for a code analysis, quality scan, or SonarQube / SonarCloud scan using the sonar-mcp server.
---

# Sonar Scan Skill

This skill contains instructions and automation guidelines for triggering SonarQube code scans through the `sonar-mcp` server. It outlines how to locate configuration settings, fallbacks, and parameter resolution logic prior to initiating a scan.

## Execution Rules & Pre-conditions

When a user requests a code analysis, quality gate check, or SonarQube scan, follow these preparation steps to construct the arguments for the scan tool.

### 1. Configuration File Parsing (`sonar.config`)
Always check the repository root for a `sonar.config` file first.
If `sonar.config` is present, read it and extract the following parameters:
- **Project Key** (`Project Key` or `projectKey`)
- **Project Name** (`Project Name` or `projectName`)
- **Version** (`Version` or `version`)
- **Exclusions** (`Exclusions` or `exclusions`)

Always read the repository root `.gitignore` as well. Resolve each non-comment `.gitignore` entry against the target repository and add it to the SonarQube exclusion configuration (`sonar.exclusions`) only when the entry matches at least one file or folder that actually exists in that repository. Do not add unmatched patterns from generic or default `.gitignore` files. Preserve any exclusions from `sonar.config` and merge both sets; translate `.gitignore` patterns to equivalent SonarQube glob patterns where their syntax differs.

### 2. Version Resolution Fallback Chain
If no version is specified in the `sonar.config` file, or if the `sonar.config` file is absent, determine the version using the following hierarchical fallback chain:

1. **`version.txt`**: Look for a file named `version.txt` in:
   - The repository root
   - Any project-specific subfolders/roots within the repository.
   If present, use its content as the version.

2. **`apm.yml`**: If `version.txt` is missing or empty, look for a file named `apm.yml` in the repository root.
   - Look for the `version` field.
   - Use its value as the version.
   
3. **`AssemblyInfo.cs`**: If neither of the above options yields a version, search for an `AssemblyInfo.cs` file under the main project's root folder.
   - Look for the `AssemblyVersion` or `AssemblyFileVersion` attribute (e.g., `[assembly: AssemblyVersion("1.0.0.0")]`).
   - Extract the version number within the quotes.

4. **`*.csproj`**: If none of the above options yields a version, search for a `.csproj` file in the main project's root folder.
   - Look for the `<Version>` or `<AssemblyVersion>` XML element.
   - Extract the inner text as the version.

### 3. Project Key & Name Fallbacks
If the project key or project name cannot be resolved from the `sonar.config` file:
- **Project Key Fallback**: Use the repository folder name as the project key. Replace all spaces with dashes (`-`).
- **Project Name Fallback**: Base the project name on the repository folder name, formatted with proper capitalization and spaces (e.g., `my-cool-project` becomes `My Cool Project`).

### 4. Branch Determination
Retrieve the currently checked-out branch name for the repository being scanned. Provide this as the target branch name parameter for the Sonar scan.

## Scan Execution Method

Use the `sonar_run_scan` tool with the following required parameters:

- `projectKey`
- `branch`
- `projectDir` (an absolute path)

The optional parameters are `extraArgs`, `timeoutMs` (10 seconds to 1 hour,
default 15 minutes), `useMsBuild`, `runTests`, `testsDir`, and `solutionFile`.
The server supplies the SonarQube URL and token from its environment; do not
put either credential in `extraArgs`.

The server rejects `extraArgs` that attempt to override `sonar.host.url`,
`sonar.token`, `sonar.login`, `sonar.password`, `sonar.projectKey`, or
`sonar.branch.name`. Pass only additional, non-protected scanner properties.

`projectName` and `version` are metadata to resolve before the scan, but they
are not direct `sonar_run_scan` parameters. Pass resolved values through
`extraArgs` using SonarQube's scanner property names:

```text
-Dsonar.projectName=<resolved project name>
-Dsonar.projectVersion=<resolved version>
```

Each property must be one array element, including when the project name
contains spaces. Include `sonar.projectName` whenever it can be resolved using
the configuration or fallback above. Include `sonar.projectVersion` only when
a non-empty version was resolved; do not invent a version or pass a placeholder.
The server passes these properties to the generic scanner and translates the
`-D` prefix for the MSBuild scanner.

### Scanner selection

- Set `useMsBuild: false` to force the generic `sonar-scanner` workflow.
- Set `useMsBuild: true` to force the MSBuild workflow.
- If `useMsBuild` is omitted, the server automatically selects MSBuild when
  `solutionFile` is provided or .NET code is found recursively (up to five
  levels deep), excluding hidden directories and `node_modules`, `bin`, `obj`,
  and `dist`. Otherwise it uses the generic scanner.

### MSBuild workflow

When MSBuild is selected, resolve the build target in this order:

1. An explicit `solutionFile` (absolute or relative to `projectDir`).
2. A single recursively discovered `.slnx`.
3. A single recursively discovered `.sln`.
4. A single recursively discovered `.csproj` or `.vbproj`.

If more than one candidate exists at the selected priority, the scan fails;
retry with `solutionFile` identifying the intended file. The selected target
is passed to both `dotnet build` and `dotnet test`, so do not use `testsDir` to
select a separate .NET test project or solution.

MSBuild test execution is enabled by `runTests: true`, disabled by
`runTests: false`, or auto-detected when omitted. Auto-detection looks for
test-named project files or `*Test.cs`/`*Tests.cs` files. When enabled, tests
write results under `<projectDir>\TestResults` and the scanner collects:

- `**/TestResults/**/coverage.opencover.xml`
- `**/TestResults/**/*.trx`

### Generic scanner workflow

For non-.NET projects, `testsDir` may be an absolute path or a path relative
to `projectDir`. If omitted, the server checks for a sibling `../tests`
directory. It runs `npm test` only when a test script is present (or when
`runTests: true` explicitly requests the configured directory), and configures
LCOV report paths for the project and discovered tests directory. `testsDir`
is ignored by the MSBuild workflow.

The `timeoutMs` value is a total timeout for the scan sequence. For MSBuild
scans it covers begin, build, test (when enabled), and end; for generic scans
it covers the optional Node test run and scanner invocation. Review the
returned output tail and then use `sonar_get_quality_gate` with the same
`projectKey` and `branch` to verify the result.
