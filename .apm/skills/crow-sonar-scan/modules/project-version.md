# Sonar project version for direct scans and CI

Use this module whenever resolving an application's `sonar.projectVersion`,
whether running `sonar_run_scan` directly or configuring a pipeline that
performs Sonar analysis.

1. Read the repository-root `crow.config` file. Use its `Version` or
   `version` field under `sonar` when non-empty; otherwise use the flat
   version field in the legacy root `sonar.config` file if present. If both
   contain different non-empty values, use the Crow value and report the
   conflict. Never add an internal Sonar endpoint or token to public
   project memory.
2. If neither configuration supplies a version, check in this order:
   - `version.txt` in the repository root or a project-specific subfolder
     or root within the repository;
   - the repository-root `apm.yml` `version`;
   - `AssemblyVersion` or `AssemblyFileVersion` in the target .NET
     application's `AssemblyInfo.cs`;
   - `<Version>` or `<AssemblyVersion>` in its `*.csproj`;
   - for a Java application, the `pom.xml` project version or Gradle
     `version` declaration (`gradle.properties` or build script).
     Resolve inherited or property-substituted versions using the
     project's own build tooling; do not submit literal `${...}` or
     `unspecified` as a version.
3. For a CI pipeline targeting one application in a multi-project
   repository, confirm that each candidate actually versions that
   application. In particular, use the root `apm.yml` only if it describes
   that application, not an unrelated tool or package. Resolve conflicting
   `version.txt` or project versions before authoring the pipeline. This
   CI-specific check does not change the existing fallback order for a
   direct Sonar MCP scan.

For a **direct MCP scan**, `sonar_run_scan` has no `version` argument. Pass
the resolved version in `extraArgs` as **one array element**:

```text
-Dsonar.projectVersion=<resolved version>
```

The MCP server translates the `-D` prefix for the MSBuild scanner. If no
non-empty version is found, omit this optional element rather than inventing
one or passing a placeholder. Keep the project's key and branch in their
own `sonar_run_scan` parameters as described by the Sonar scan skill.

For a **CI scan**, pass the resolved version through the selected scanner's
or provider extension's supported `sonar.projectVersion` property syntax.
When a verified build-time source exists, resolve it in the target job
instead of hardcoding an environment-specific value. Check that the actual
scanner receives it. If no relevant version can be verified, omit the
optional property and report why. Do not use a per-build counter as the
application version: Sonar's new-code baseline may depend on version
changes.
