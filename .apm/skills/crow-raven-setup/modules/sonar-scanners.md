# SonarScanner Setup and Maintenance

## Trigger and execution boundary

Use this module when the active session exposes `sonar_run_scan`, the
selected client's configured MCP servers include `sonar` (Crow/Raven's
catalog ID) or `sonar-mcp`, or the user selects the `sonar` server during the
current Raven setup. A project's `crow.config.sonar` section alone is not
evidence that the Sonar MCP server is installed.

The `crow-raven-setup.mjs` script manages Raven and
codebase-memory-mcp; it does not manage Sonar scanners. The Raven Setup Agent
executes scanner release lookups and approved scanner commands with its
`execute` tool. Keep scanner operations separate from the Raven setup plan and
state. Surface command failures explicitly, and never report success unless
the install or update and its verification complete. Do not run a Sonar
analysis unless the user separately asks for a scan.

## Inventory and prerequisites

Inspect both scanner tools independently:

- Locate the generic CLI with `Get-Command sonar-scanner` or
  `Get-Command sonar-scanner.bat` on Windows, and `command -v sonar-scanner`
  on macOS or Linux. Run `sonar-scanner --version` (or
  `sonar-scanner.bat --version` on Windows).
- Check the SDK with `dotnet --version` and `dotnet --list-sdks`, then compare
  the installed SDKs with the selected scanner release's documented
  requirements. Use `dotnet tool list --global` to identify an installed
  global tool and verify its exact package version. Only when a compatible SDK
  is available, run `dotnet sonarscanner` without arguments to confirm the
  command starts and prints its usage; do not run `begin` or `end` as a setup
  check. Do not use `dotnet sonarscanner --version`: it is not a supported
  version-query command and exits with a usage error.

MCP does not expose another process's `PATH`. Inspect an explicit `env.PATH`
in the selected client's server configuration when present; otherwise compare
against the user-level environment used to launch the client. Do not read or
display credentials while inspecting configuration. If the MCP process's
effective environment cannot be established, report local installation as
verified but MCP visibility as unverified; do not claim the scanner is ready
for that server. If a PATH or client-configuration change is needed, include
its exact effect in the preview and obtain confirmation. Preserve existing
PATH entries, restart the MCP server or client when required, and re-check
visibility after restart.

The .NET SDK is required for the global `dotnet-sonarscanner` tool. Check its
version against the selected scanner release's official requirements. If no
compatible SDK is installed, report that MSBuild scanning is blocked and ask
separately whether the user wants official .NET SDK installation guidance.
Approval to install SonarScanner is not approval to install the SDK. Do not
install the SDK implicitly or report an unavailable .NET scanner command as
a failed verification.

## Resolve stable versions

Resolve the latest stable version at invocation time from the official
sources:

- [SonarScanner CLI documentation and downloads](https://docs.sonarsource.com/sonarqube-server/analyzing-source-code/scanners/sonarscanner/)
- [SonarScanner for .NET installation guide](https://docs.sonarsource.com/sonarqube-server/analyzing-source-code/scanners/dotnet/installing/)
- [NuGet `dotnet-sonarscanner` versions](https://www.nuget.org/packages/dotnet-sonarscanner#versions-body-tab)

Use the vendor's current compatibility guidance for the configured SonarQube
server version when it can be determined without exposing credentials. Also
check the .NET SDK requirements for `dotnet-sonarscanner`. If either version
is unknown, report that compatibility is unverified and do not describe the
scanner as confirmed compatible. Use exact stable versions, never a
prerelease or a version copied from an old prompt. If an official release
source is unavailable, report the failure and defer the install or update
rather than guessing.

## Preview and install

Before any install or update, show a separate scanner plan containing:

- the detected and target exact versions for each scanner;
- official release/download links and platform/architecture;
- the user-local installation path and MCP-process PATH/configuration impact;
- published checksum or signature verification, if available;
- installed .NET SDK version and compatibility status for the MSBuild scanner;
- the prior version/path and exact rollback action; and
- the user-local state file to be created or updated.

Require explicit confirmation before executing the plan. Install the generic
CLI from the exact platform archive linked by the official documentation into
a versioned user-local directory under
`~/.crow/sonar-scanners/sonar-scanner-cli/<version>/`, keeping the existing
installation until verification succeeds. Keep the active path stable at
`~/.crow/sonar-scanners/sonar-scanner-cli/current/bin` and update its
versioned directory link only after the staged scanner verifies. Install or
update the MSBuild scanner as an exact versioned .NET global tool:

```text
dotnet tool install --global dotnet-sonarscanner --version <exact-version>
dotnet tool update --global dotnet-sonarscanner --version <exact-version>
```

Use the install command only when the global tool is absent and the update
command when it is already installed. Use official HTTPS downloads and verify
published checksums or signatures against the downloaded archive (for example,
`Get-FileHash -Algorithm SHA256` on Windows or `sha256sum` on Linux). If the
publisher provides no checksum or signature, disclose that and rely only on
the official HTTPS source. Do not modify project files, add project tool
manifests, or change system-wide configuration as a side effect.

## State and rollback

Keep scanner tracking separate from Crow Raven setup state at
`~/.crow/sonar-scanners/state.json`. Use this shape, with `null` for values
that are not yet installed:

```json
{
  "schemaVersion": 1,
  "lastCheckedAt": null,
  "cli": {
    "version": null,
    "path": null,
    "previousVersion": null,
    "previousPath": null
  },
  "dotnetMsbuild": {
    "version": null,
    "previousVersion": null
  }
}
```

It may contain only a schema version, check timestamp, current and previous
scanner versions, and local install paths. It must not contain server URLs,
credentials, or provider responses. Create or change it only after preview
and confirmation. For `dotnetMsbuild`, record `previousVersion: null` only
when pre-install inventory confirmed that the global tool was absent; after a
successful first-time installation, this means rollback must restore the
previous state by uninstalling the tool. If the prior tool state is unknown,
stop and report the mismatch instead of treating it as absent.

Before an update, save the exact previous CLI path/version and .NET tool
version in the state file. Update recorded current versions only after the
installed commands report the expected versions. If verification fails,
restore the previous CLI path. For the .NET scanner, run
`dotnet tool update --global dotnet-sonarscanner --version <previous-version>`
when a previous version is recorded; when `previousVersion` is null because
pre-install inventory confirmed the tool was absent, run
`dotnet tool uninstall --global dotnet-sonarscanner` and verify it is no longer
listed. On a later rollback request, show the current and previous versions,
obtain confirmation, restore the previous CLI path and .NET tool version, or
uninstall the .NET tool when its recorded previous version is null. Update the
state only after verifying the restored versions or absence. Report rollback
failures explicitly.

## Freshness and verification

On every setup or scanner-maintenance invocation where Sonar MCP is
configured, compare both installed versions to the current stable releases
from the official sources above. Do not wait for Raven's 24-hour freshness
timestamp. Report available updates and install them only after confirmation;
if the user declines, report which scanner remains behind. The Raven setup
CLI and optional Copilot update hook do not track SonarScanner versions, so
scanner checks require invoking the Raven Setup Agent.

After setup or update, verify the exact CLI version and confirm the exact
.NET scanner package version with `dotnet tool list --global`. Only when the
SDK is compatible, run `dotnet sonarscanner` without arguments to confirm it
starts and displays usage; do not run `begin` or `end`. If no compatible SDK
is available, skip that command check and report MSBuild scanning as blocked.
Confirm that the selected MCP server's configured or inherited PATH resolves
each installed executable. If visibility cannot be verified without running
an analysis, report the limitation and do not claim the scanner is ready for
Sonar MCP.
