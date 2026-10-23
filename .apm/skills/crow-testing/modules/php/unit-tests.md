# PHP unit tests

Inspect the existing Composer scripts, test runner (PHPUnit, Pest, or another established tool), autoloading, fixtures, and PHP version before selecting commands. Follow repository conventions; if starting a suite, choose a maintained runner compatible with the supported PHP version.

- Exercise business rules without booting the web framework or connecting to real external services. Use small fakes at owned boundaries, not mocks of every internal call; assert observable outcomes, including invalid, boundary, ownership, and dependency-failure paths.
- Use data providers for compact rule matrices and controlled clocks/randomness for deterministic tests. Include representative multilingual/Indigenous-language text and relevant byte/code-point/grapheme cases.
- Test invalid input and failures as explicit assertions rather than suppressing notices or accepting a swallowed exception. Confirm the runner discovers nonzero tests, reports failures to CI, and runs with the target PHP version/extensions.
- When changing a legacy suite or test framework, run old and new tests against the same behavior before removal. A test that boots a full framework or uses a real database belongs in integration coverage.

## Sources

- PHPUnit, [version-specific documentation](https://phpunit.de/documentation.html)
- PHP, [grapheme functions](https://www.php.net/manual/en/ref.intl.grapheme.php)
