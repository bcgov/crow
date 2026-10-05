# Package Manager Inventory and Routing

Use this module to identify the package manager for each project root, locate
its declarations and resolved dependency data, and choose the correct update
workflow. The list covers common, legacy, and non-standard manifests; it is a
routing catalog, not permission to update every detected ecosystem. If a
repository uses another manager, inspect its build scripts and pinned toolchain
and apply the same evidence, lockfile, and verification requirements.

## Inventory and Routing Rules

1. Search each application, workspace, and deployable root for the indicators
   below, plus wrappers, central version catalogs, toolchain pins, and CI
   restore/build commands. Do not skip nested projects just because the
   repository has a root manifest.
2. Use the manager selected by the repository's scripts, wrapper, `packageManager`
   field, toolchain pin, or documented workflow. If multiple managers could
   own the same project, report the ambiguity and ask before changing files.
   Workspace orchestrators such as Nx, Lerna, and Turborepo do not replace the
   underlying package manager.
3. Treat source declarations, version catalogs, overrides, registries, and
   lockfiles as one resolution chain. Inventory direct declarations and the
   manager-resolved transitive graph. A manifest alone may not contain the
   exact resolved versions; caches and installed directories are not the
   source of truth.
4. Update declarations with the repository-pinned manager or wrapper, then
   regenerate the corresponding lockfiles. Preserve workspace boundaries,
   private registry settings, integrity/checksum policy, package sources, and
   prerelease policy. Do not hand-edit generated lockfiles or silently replace
   the project's manager.
5. Runtime, SDK, compiler, language, and primary-framework version pins route
   to `crow-framework-updates`, even when the requested version increment is
   patch or minor. Route libraries, plugins, tools, and assets to this
   dependency-update skill.

## Language and Application Ecosystems

| Technology | Managers and common indicators | Routing notes |
|---|---|---|
| .NET / F# / VB | **NuGet**: `*.csproj`, `*.fsproj`, `*.vbproj`, `Directory.Packages.props`, `packages.config`, `packages.lock.json`, `NuGet.Config`; **Paket**: `paket.dependencies`, `paket.lock`, `paket.references`; **.NET tools**: `.config/dotnet-tools.json` | Use the pinned .NET SDK or Paket tool. Inspect central package versions, target frameworks, sources, and per-project lock files together. Update .NET tools as development dependencies; `global.json` SDK pins and .NET runtimes route to `crow-framework-updates`. |
| .NET browser assets | **Microsoft Library Manager (LibMan)**: `libman.json` | This manages client-side library files and is not NuGet. Inspect each library ID, provider, exact version, destination, and source. Verify the target version, then use the repository's LibMan CLI (`libman update <library> --to <verified-version>` and `libman restore`) and review changed files under each destination. Defer if LibMan cannot apply the exact verified version. The CLI does not provide an `outdated` inventory; check the provider's published versions before updating. See the [LibMan CLI reference](https://learn.microsoft.com/en-us/aspnet/core/client-side/libman/libman-cli). |
| JavaScript / TypeScript / Node.js | **npm**: `package.json`, `package-lock.json`, `npm-shrinkwrap.json`; **pnpm**: `pnpm-lock.yaml`, `pnpm-workspace.yaml`; **Yarn**: `yarn.lock`, `.yarnrc.yml`; **Bun**: `bun.lock`, legacy `bun.lockb`; workspaces and `packageManager` fields may select the tool | Follow the pinned manager and lockfile (`npm`, `pnpm`, `yarn`, or `bun`). Check workspace roots, `engines`, overrides/resolutions, catalogs, and package-manager version pins. Do not mix managers or regenerate a different lockfile. |
| Deno / JavaScript runtimes | **Deno**: `deno.json`, `deno.jsonc`, `deno.lock`, import maps, `jsr:` and `npm:` specifiers | Use the repository-pinned Deno CLI and its current documented dependency commands. Check import maps, tasks, lockfile, and permissions together; do not treat an npm lockfile as covering Deno-only imports. |
| Browser-only JavaScript (legacy) | **Bower**: `bower.json`, `.bowerrc` | Treat as a legacy manager. Preserve the configured registry and resolver; do not migrate to npm unless requested. |
| Java / Android / JVM | **Maven**: `pom.xml`, `.mvn/`, `mvnw`, BOMs and `dependencyManagement`; **Gradle**: `build.gradle`, `build.gradle.kts`, `gradle/libs.versions.toml`, `gradle.lockfile`, `gradlew`; **Ivy**: `ivy.xml`, `ivysettings.xml` (legacy) | Use the checked-in wrapper. Review plugins, processors, BOMs, constraints, catalogs, repositories, and lock/verification metadata as well as libraries. Gradle wrapper/plugins are development tools and route here; JDK/runtime/compiler changes route to `crow-framework-updates`. |
| Scala | **sbt**: `build.sbt`, `project/*.scala`, `project/build.properties`; **Mill**: `build.sc`, `.mill-version`; **Coursier**: `project/` or `.scala-build/` metadata | Follow the repository's launcher and resolver. Scala, JDK, and compiler/runtime version changes route to `crow-framework-updates`; sbt, Mill, Coursier, and library-coordinate updates route here. |
| Clojure | **Clojure CLI / tools.deps**: `deps.edn`; **Leiningen**: `project.clj`, `profiles.clj`; **Boot**: `build.boot` (legacy) | Inspect aliases, profiles, repositories, and lock or pinned dependency data where used. Do not translate between tools as part of a routine update. |
| Python | **pip**: `requirements*.txt`, constraints files, `setup.cfg`, `setup.py`; **pip-tools**: `requirements*.in`, compiled requirements; **uv**: `pyproject.toml`, `uv.lock`; **Poetry**: `pyproject.toml`, `poetry.lock`; **PDM**: `pyproject.toml`, `pdm.lock`; **Pipenv**: `Pipfile`, `Pipfile.lock`; **Conda/Mamba**: `environment.yml`, `environment.yaml`, `conda-lock.yml`; **Pixi**: `pixi.toml`, `pixi.lock`; **Hatch** and **Rye**: project configuration and lock files selected by the repository | Respect the selected environment and lock generator. Check optional groups, extras, constraints, Python version markers, channels, and platform-specific resolution. Python interpreter pins route to `crow-framework-updates`. Do not regenerate a pip lock from a different Python version or platform without confirming the repository's target. |
| Go | **Go Modules**: `go.mod`, `go.sum`, `go.work` | Use the pinned Go toolchain and module/workspace context. Preserve `replace`, `exclude`, vendoring, and checksum behavior; distinguish toolchain directives from module versions. |
| Rust | **Cargo**: `Cargo.toml`, `Cargo.lock`, workspace manifests, `.cargo/config.toml` | Use the repository's Rust toolchain and Cargo. Check workspace members, feature flags, target-specific dependencies, patches, and source replacement. Rust toolchain pins route to `crow-framework-updates`. |
| Ruby | **Bundler**: `Gemfile`, `Gemfile.lock`, `gemspec`, `.ruby-version`, `.bundle/config`; **RubyGems**: `*.gemspec` | Use the pinned Ruby/Bundler versions. Check groups, platforms, sources, path/git dependencies, and lockfile platform sections. Ruby runtime changes route to `crow-framework-updates`. |
| PHP | **Composer**: `composer.json`, `composer.lock`; **PEAR/PECL**: `package.xml`, extension configuration (legacy) | Use the repository's pinned PHP and Composer. Keep `require` and `require-dev`, platform constraints, plugins, repositories, and extension requirements consistent. PHP runtime changes route to `crow-framework-updates`. |
| Swift / Objective-C | **Swift Package Manager**: `Package.swift`, `Package.resolved`; **CocoaPods**: `Podfile`, `Podfile.lock`; **Carthage**: `Cartfile`, `Cartfile.resolved` | Confirm which resolver the Xcode project uses. Check deployment targets, binary artifacts, and lockfiles; do not migrate dependency managers as part of an update. |
| Dart / Flutter | **Pub**: `pubspec.yaml`, `pubspec.lock`, `pubspec_overrides.yaml` | Use the pinned Dart/Flutter SDK. Check SDK constraints, dependency overrides, workspace packages, and platform-specific plugins. SDK changes route to `crow-framework-updates`. |
| Elixir / Erlang | **Mix / Hex**: `mix.exs`, `mix.lock`; **Rebar3 / Hex**: `rebar.config`, `rebar.lock`; `rebar.config.script` | Use the repository's pinned Erlang/Elixir and build tool. Inspect OTP constraints, plugins, overrides, and applications as well as libraries. Runtime changes route to `crow-framework-updates`. |
| Haskell | **Cabal**: `*.cabal`, `cabal.project`, `cabal.project.freeze`; **Stack**: `stack.yaml`, `stack.yaml.lock` | Use the checked-in resolver/compiler pin and the project-selected tool. Keep package index snapshots and compiler constraints intact. |
| OCaml | **opam**: `*.opam`, `opam`, `opam.locked`, `dune-project` | Use the pinned opam switch/compiler and project lock data. Do not update compiler/toolchain pins as library updates. |
| R | **renv**: `renv.lock`; **pak** and base `install.packages`: `DESCRIPTION`, `NAMESPACE`; **Packrat**: `packrat.lock` (legacy) | Use the repository's selected library snapshot and R version. Preserve repositories, package sources, and platform/binary constraints. |
| Julia | **Pkg**: `Project.toml`, `Manifest.toml` | Use the pinned Julia version and project environment; preserve compat bounds and registry/source settings. |
| Perl | **CPAN/cpanm**: `cpanfile`; **Carton**: `cpanfile.snapshot`, `local/` metadata | Use the repository's pinned Perl and CPAN client. Distinguish declared prerequisites from the resolved snapshot. |
| Lua | **LuaRocks**: `*.rockspec`, `luarocks.lock`, `.luarocks/` | Use the selected Lua/LuaRocks version and configured rocks servers. Preserve native build and platform constraints. |
| Fortran | **fpm**: `fpm.toml`, `fpm.lock` | Use the pinned Fortran compiler and fpm. Compiler version and ABI changes route to `crow-framework-updates`. |

## Native, Container, and Infrastructure Dependencies

These inputs are not all application-language package managers, but they
commonly carry versioned dependencies. Process them only when they are within
the requested scope and use their owning tool rather than forcing them
through a language package manager.

| Technology / surface | Managers and indicators | Routing notes |
|---|---|---|
| C / C++ | **vcpkg**: `vcpkg.json`, `vcpkg-configuration.json`, `vcpkg-lock.json`; **Conan**: `conanfile.py`, `conanfile.txt`, `conan.lock`; **CMake FetchContent / CPM.cmake**: `CMakeLists.txt`, `cmake/`; **Meson WrapDB**: `meson.build`, `subprojects/*.wrap`; **Bazel/Bzlmod**: `MODULE.bazel`, `MODULE.bazel.lock`, legacy `WORKSPACE` | Follow the project's selected build integration and pinned compiler. Review triplets, profiles, toolchain files, hashes, and source revisions. vcpkg, Conan, CMake, Meson, and Bazel tool/package updates route here; compiler/runtime changes route to `crow-framework-updates`. |
| Nix | **Nix / flakes**: `flake.nix`, `flake.lock`, `default.nix`, `shell.nix` | Use the repository's pinned Nix version and lock inputs; distinguish system/toolchain inputs from application packages. |
| Container OS packages | **APT/dpkg**, **Alpine apk**, **DNF/YUM/RPM**, **Zypper**, **Pacman**: package install commands and repositories in `Dockerfile`, image build scripts, or OS manifests | Inspect base image and distribution first. Update only packages in scope, pin versions where the project does, rebuild the image, and run image-level checks. Base image/runtime changes route to `crow-framework-updates`. |
| Developer workstation tools | **Homebrew**: `Brewfile`; **Chocolatey**: package manifests / `packages.config`; **WinGet**: exported package lists and manifest YAML; **Scoop**: bucket manifests / `scoopfile.json` | These are environment/tool dependencies, not application lockfiles. Update only if the repository owns the manifest; preserve package IDs, versions, sources, and platform scope. |
| Terraform / OpenTofu | Provider requirements and module sources in `*.tf`; `.terraform.lock.hcl` | Use the repository-pinned CLI. Review provider constraints and module source versions separately; inspect the plan after lock updates. Do not use an unrestricted upgrade to change all providers/modules. |
| Helm | `Chart.yaml`, `Chart.lock`, legacy `requirements.yaml` | Use the pinned Helm CLI and update only declared chart dependencies; review the regenerated lock and rendered output. |
| Ansible | `requirements.yml` for Galaxy roles and collections; execution-environment dependency files | Use the repository's pinned `ansible-galaxy` / execution-environment tooling. Keep role and collection versions constrained. |
| Git dependencies and CI actions | `.gitmodules`; workflow `uses:` references such as `.github/workflows/*.yml` | These are source-control/workflow references rather than ordinary package-manager dependencies. Preserve immutable revisions and explicitly requested update scope; verify submodule or workflow behavior after changes. |
| Container images | `FROM` instructions, Compose `image:` values, Kubernetes image references, image lock/digest files | Image tags/digests are deployment inputs. Verify publisher, supported line, architecture, and digest policy; runtime/base-image changes route to `crow-framework-updates`. |

## Stop and Report

- If multiple manifests describe the same project, identify the active one from
  build scripts, wrappers, CI, or repository documentation before updating.
- If a lockfile is missing, stale, generated by a different tool, or cannot be
  regenerated with the pinned manager, stop and report the exact conflict.
- Do not treat a package-manager registry, lockfile, cache, vendored directory,
  or manifest's version range as proof that a particular release is current or
  safe. Verify the exact candidate with the owning manager or an authoritative
  source and report unavailable checks.
