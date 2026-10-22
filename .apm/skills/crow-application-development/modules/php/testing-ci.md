# PHP testing, Composer, image, and CI guidance

- Use the repository's pinned PHP/Composer, existing formatter/static analyzer, test runner, and scripts. Load the PHP unit/integration modules from `crow-testing` only for the relevant test work; do not substitute a new framework without a decision.
- Validate `composer.json` and install exact locked versions with `composer install`, not `composer update`, in CI. Commit `composer.lock` for applications; a library package may use a different lockfile policy. Check actual platform requirements/extensions and run `composer audit --locked` on the lockfile when supported by the pinned Composer version; a missing lockfile or unavailable audit must be reported, not treated as a pass.
- Review Composer plugins and scripts as executable build dependencies. Allow only trusted plugins and preserve the project's intended execution policy; do not indiscriminately disable scripts that the build requires.
- Keep `require-dev` dependencies for checks in CI; omit them only in the production artifact after tests. Run the existing linter/static analysis first, then unit and integration suites, packaging, and established quality gates; assert expected suites and reports exist instead of accepting a zero-test pass.
- When SonarQube coverage is required, generate a Clover XML report with the project's coverage driver (for PHPUnit, `--coverage-clover=<path>`) before scanning and set `sonar.php.coverage.reportPaths` to that report. Verify Sonar imports it and the configured gate blocks on missing or insufficient coverage; JavaScript LCOV is not PHP coverage.
- Build on a supported, patched PHP image compatible with required extensions and FPM/CLI roles. Prefer non-root runtime, minimal writable paths, explicit locales, no embedded secrets or dev tooling in the production image, and test the actual web-server/FPM pairing where configuration matters.
- Package the verified application and database migrations without running migrations against shared data in CI. Promote the same artifact. Keep credentials and privileged network paths away from untrusted PR jobs; scan dependencies and image against the team's policy, with reviewed exceptions and expiry.

## Sources

- Composer, [install command](https://getcomposer.org/doc/03-cli.md#install-i)
- Composer, [audit command](https://getcomposer.org/doc/03-cli.md#audit)
- Composer, [check-platform-reqs command](https://getcomposer.org/doc/03-cli.md#check-platform-reqs)
- Composer, [lockfile policy](https://getcomposer.org/doc/01-basic-usage.md#commit-your-composer-lock-file-to-version-control)
- PHP, [supported versions](https://www.php.net/supported-versions.php)
- SonarSource, [PHP test coverage](https://docs.sonarsource.com/sonarqube-server/analyzing-source-code/test-coverage/php-test-coverage/)
