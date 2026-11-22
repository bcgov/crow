# Framework, Runtime, and Dependency Audit

Load during a security review's version and dependency audit. This module provides reusable version-source, support-lifecycle, outdated-scan, license, and CVE checks; it does not authorize upgrades.

## Framework & Runtime Version Audit

Inspect repository configuration, build files, and runtime tools to determine exact versions and support phases:
1. **Runtimes & SDKs:**
   - **Java**: Inspect `pom.xml` (`<java.version>`), `build.gradle`, `.java-version`, or run `java -version`.
   - **.NET**: Inspect `*.csproj` (`<TargetFramework>`), `global.json`, `libman.json`, or run `dotnet --version`.
   - **JavaScript / Node.js / TypeScript**: Inspect `package.json` (`engines`, `nvmrc`), `.nvmrc`, `tsconfig.json`.
   - **PHP**: Inspect `composer.json` (`php` requirement), `.php-version`.
   - **Python**: Inspect `runtime.txt`, `pyproject.toml`, `Pipfile`, `setup.py`.
   - **Go**: Inspect `go.mod` (`go` directive).
2. **Frameworks & Web Servers:**
   - **Java**: Spring Boot, Quarkus, Micronaut versions in build manifests.
   - **.NET**: ASP.NET Framework, ASP.NET Core, EF Core versions in `.csproj` / `packages.lock.json`.
   - **JS**: React, Angular, Vue, Vite, Next.js, Express, NestJS versions in `package.json`.
   - **PHP**: Laravel, Symfony, WordPress versions in `composer.json`.
3. **Container Images:**
   - Parse `Dockerfile` `FROM` instructions for base image tags (e.g. `mcr.microsoft.com/dotnet/aspnet:10.0`, `eclipse-temurin:21-jre-alpine`, `node:20-bookworm-slim`).
4. **EOL Status Verification & Major Upgrade Recommendations:**
   - Cross-reference runtime and framework major versions against official support matrices and EOL schedules (e.g., endoflife.date). Mark as `Active`, `Maintenance`, or `End-of-Life (EOL)`.
   - **Major Upgrade Trigger:** Whenever a framework or runtime major version is approaching or past its End-of-Life date (e.g., within 6 months of EOL or already EOL), you **MUST** explicitly recommend a major version upgrade to the next supported LTS/stable major release (e.g., recommend upgrading .NET 6 -> .NET 10, Spring Boot 2 -> 3, Angular 12 -> 17).

## Third-Party Dependency & Vulnerability (CVE) Audit

Parse lock files and dependency manifests to inventory third-party libraries while enforcing strict CLI outdated scan verification rules:

1. **Lock Files & Manifests:** `package-lock.json`, `pnpm-lock.yaml`, `yarn.lock`, `packages.lock.json`, `pom.xml`, `build.gradle`, `composer.lock`, `libman.json`, `requirements.txt`, `Pipfile.lock`, `go.sum`, `Cargo.lock`.

2. **Mandatory CLI Outdated Scan:**
   Before building the dependency inventory table, the agent **MUST** run ecosystem-native CLI outdated inspection tools for the project's tech stack:
   - **.NET:** `dotnet list package --outdated`
   - **Node.js:** `npm outdated` (or `pnpm outdated` / `yarn outdated`)
   - **PHP:** `composer outdated`
   - **Python:** `pip list --outdated`
   - **Java / Go / Other:** Execute native CLI outdated tools or plugin targets (e.g. `mvn versions:display-dependency-updates`, `go list -m -u all`).

3. **Never Mirror Resolved Version to Latest:**
   - Never infer `Latest Version` from a manifest or lockfile. Confirm it
     through the ecosystem's outdated CLI or a direct registry query.
   - Use exact stable versions, not wildcards or ranges (`10.0.x`, `^2.1`,
     `~1.4`, `*`).

4. **Automated Workflow Verification Check:**
   - **Pre-Write Audit Verification:** Prior to writing or updating the final dependency table in `security-review.md`, verify that CLI outdated scan commands have been executed in the current session.
   - If a CLI outdated command failed or the CLI tool is absent, explicitly document the attempted command and its result, and verify latest versions via direct package registry / web lookup before writing the document.

5. **Deprecation & Maintenance Check:** Apply the
   [dependency maintenance signals](../SKILL.md#dependency-maintenance-signals)
   check to inventoried libraries, including those with no newer release;
   record the results in the review template.

6. **Licenses:** Extract license metadata (`MIT`, `Apache-2.0`, `BSD-3-Clause`, `GPL-3.0`, `LGPL`, etc.). Flag restrictive or copyleft licenses.

7. **Known CVE Assessment:**
   - Check dependency versions against known vulnerability databases or SonarQube SCA findings.
   - Record CVE ID, affected component, severity (`Critical`, `High`, `Medium`, `Low`, `Informational`), fixed version, and remediation status.
