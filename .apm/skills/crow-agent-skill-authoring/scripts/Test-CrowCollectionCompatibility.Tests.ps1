$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'CrowCollectionCompatibility.ps1')
$fixtureRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('crow-wrapper-contract-' + [guid]::NewGuid().ToString('N'))
$utf8 = [System.Text.UTF8Encoding]::new($false)
$wrapperNames = @('starter-package', 'security-remediation')
$rootManifest = @'
name: bcgov-crow
version: 0.19.0
includes:
  - .apm/agents
  - .apm/skills
dependencies: {}
'@

function Write-ContractFixture {
    param([string]$RelativePath, [string]$Content)
    $path = Join-Path $fixtureRoot $RelativePath
    [void][System.IO.Directory]::CreateDirectory((Split-Path -Parent $path))
    [System.IO.File]::WriteAllText($path, $Content, $utf8)
}

function Get-WrapperFixture {
    param([string]$Name)
    return @"
name: bcgov-crow-$Name
version: 0.19.0
description: Synthetic compatibility wrapper
dependencies:
  apm:
    - git: https://github.com/bcgov/crow.git
      ref: v0.19.0
"@
}

function Reset-ContractFixture {
    if (Test-Path -LiteralPath $fixtureRoot) { Remove-Item -LiteralPath $fixtureRoot -Recurse -Force }
    Write-ContractFixture 'apm.yml' $rootManifest
    foreach ($name in $wrapperNames) {
        Write-ContractFixture "collections/$name/apm.yml" (Get-WrapperFixture $name)
        Write-ContractFixture "collections/$name/README.md" "bcgov/crow/collections/$name#v0.19.0`nbcgov/crow#stable"
    }
}

function Assert-ContractError {
    param([string]$Expected, [string]$Scenario)
    $report = Get-CrowCollectionCompatibilityReport -RepoRoot $fixtureRoot
    if (@($report.Errors | Where-Object { $_.Contains($Expected) }).Count -eq 0) {
        throw "$Scenario did not report '$Expected': $($report.Errors -join ' | ')"
    }
    Write-Host "Passed: $Scenario"
}

try {
    Reset-ContractFixture
    $report = Get-CrowCollectionCompatibilityReport -RepoRoot $fixtureRoot
    if ($report.Errors.Count -ne 0 -or $report.Manifests.Count -ne 2 -or $report.RootPackage.Includes.Count -ne 2) {
        throw "Valid wrapper contract failed: $($report.Errors -join ' | ')"
    }
    Write-Host 'Passed: Exactly two version-aligned full-root wrappers are accepted'

    $valid = Get-WrapperFixture 'starter-package'
    $cases = @(
        @{ Content = $valid.Replace('https://github.com/bcgov/crow.git', 'https://github.com/example/other.git'); Error = 'dependency source'; Name = 'Wrong root source' },
        @{ Content = $valid.Replace('ref: v0.19.0', 'ref: v0.18.1'); Error = 'dependency ref'; Name = 'Wrong root ref' },
        @{ Content = $valid.Replace('ref: v0.19.0', 'ref: stable'); Error = 'dependency ref'; Name = 'Mutable root ref' },
        @{ Content = $valid.Replace('version: 0.19.0', 'version: 0.18.1'); Error = 'wrapper version'; Name = 'Wrapper version mismatch' },
        @{ Content = $valid.Replace('bcgov-crow-starter-package', 'bcgov-crow-renamed'); Error = 'wrapper identity'; Name = 'Changed legacy identity' },
        @{ Content = $valid + "`n      path: .apm/skills/crow-testing"; Error = 'path or subset'; Name = 'Injected virtual asset subset' },
        @{ Content = $valid + "`n      path: .."; Error = 'path or subset'; Name = 'Injected parent traversal' },
        @{ Content = $valid + "`n      path: ."; Error = 'path or subset'; Name = 'Injected explicit root path' },
        @{ Content = $valid + "`nincludes:`n  - .apm/agents"; Error = 'publication subsets'; Name = 'Injected publication subset' },
        @{ Content = $valid + "`n      skills: [crow-testing]"; Error = 'unsupported dependency syntax'; Name = 'Injected skill filter' },
        @{ Content = $valid + "`n      ref: v0.19.0"; Error = 'duplicate dependency field'; Name = 'Duplicate dependency ref' },
        @{ Content = $valid + "`nversion: 0.19.0"; Error = 'duplicate manifest field'; Name = 'Duplicate manifest version' },
        @{ Content = $valid + "`n  apm:`n    - git: https://github.com/bcgov/crow.git`n      ref: v0.19.0"; Error = 'duplicate apm'; Name = 'Duplicate APM list' },
        @{ Content = $valid + "`n    - git: https://github.com/bcgov/crow.git`n      ref: v0.19.0"; Error = 'exactly one'; Name = 'Duplicate full-root dependency' },
        @{ Content = $valid.Replace("      ref: v0.19.0", ''); Error = 'dependency ref'; Name = 'Missing root ref' },
        @{ Content = $valid.Replace("    - git: https://github.com/bcgov/crow.git", '    - bcgov/crow#v0.19.0'); Error = 'unsupported dependency syntax'; Name = 'Shorthand instead of explicit Git source' },
        @{ Content = "author:`n  name: bcgov`n  includes: .apm/agents`n$valid"; Error = 'unsupported manifest syntax'; Name = 'Injected author subfield' },
        @{ Content = "author:`n  name: bcgov`n  name: other`n$valid"; Error = 'duplicate author field'; Name = 'Duplicate author subfield' },
        @{ Content = "author:`n  name: {includes: .apm/agents}`n$valid"; Error = 'unsupported author scalar syntax'; Name = 'Author nested flow mapping' },
        @{ Content = "author:`n  name: |`n    copied text`n$valid"; Error = 'unsupported author scalar syntax'; Name = 'Author block scalar' },
        @{ Content = "keywords:`n  - crow`n  includes: .apm/agents`n$valid"; Error = 'unsupported manifest syntax'; Name = 'Injected keyword mapping' },
        @{ Content = "keywords: [crow]`n$valid"; Error = 'explicit block form'; Name = 'Inline keyword syntax' },
        @{ Content = $valid.Replace('description: Synthetic compatibility wrapper', "description: Synthetic compatibility wrapper`n  includes: .apm/agents"); Error = 'unsupported manifest syntax'; Name = 'Indented syntax under scalar metadata' },
        @{ Content = "name: bcgov-crow-starter-package`nversion: 0.19.0`ndependencies:`n  apm: []"; Error = 'exactly one'; Name = 'Missing full-root dependency' }
    )
    foreach ($case in $cases) {
        Reset-ContractFixture
        Write-ContractFixture 'collections/starter-package/apm.yml' $case.Content
        Assert-ContractError $case.Error $case.Name
    }
    Reset-ContractFixture
    Write-ContractFixture 'collections/starter-package/apm.yml' ("author:`n  name: bcgov`n  email: crow@example.invalid`n  url: https://example.invalid`nkeywords:`n  - crow-starter-package`n$valid")
    $report = Get-CrowCollectionCompatibilityReport -RepoRoot $fixtureRoot
    if ($report.Errors.Count -gt 0) { throw "Allowed metadata failed: $($report.Errors -join ' | ')" }
    Write-Host 'Passed: Explicit allowed author fields and keyword entries'
    Reset-ContractFixture
    Remove-Item -LiteralPath (Join-Path $fixtureRoot 'collections/security-remediation') -Recurse -Force
    Assert-ContractError 'Exactly two' 'Missing legacy wrapper'
    Reset-ContractFixture
    Write-ContractFixture 'collections/duplicate/apm.yml' $valid
    Assert-ContractError 'Exactly two' 'Additional wrapper with duplicate package identity'
    Reset-ContractFixture
    Write-ContractFixture 'collections/starter-package/.apm/agents/copied.agent.md' '# Own asset'
    Assert-ContractError 'no own assets' 'Own asset injected into wrapper'
    Reset-ContractFixture
    Remove-Item -LiteralPath (Join-Path $fixtureRoot 'collections/starter-package/apm.yml')
    Assert-ContractError 'manifest is missing' 'Missing wrapper manifest'
    Reset-ContractFixture
    Remove-Item -LiteralPath (Join-Path $fixtureRoot 'collections/starter-package/README.md')
    Assert-ContractError 'README is missing' 'Missing wrapper documentation'
    Reset-ContractFixture
    Write-ContractFixture 'apm.yml' ($rootManifest.Replace('dependencies: {}', @'
dependencies:
  apm:
    - git: https://github.com/bcgov/crow.git
      path: collections/starter-package
      ref: v0.19.0
'@))
    Assert-ContractError 'no wrapper cycle' 'Root-to-wrapper cycle'
    Reset-ContractFixture
    Write-ContractFixture 'apm.yml' ($rootManifest + "`ndevDependencies:`n  apm: []")
    Assert-ContractError 'no wrapper cycle' 'Root development dependency bypass'
    Reset-ContractFixture
    Write-ContractFixture 'apm.yml' ($rootManifest.Replace('name: bcgov-crow', 'name: another-package'))
    Assert-ContractError 'root package identity' 'Wrong full-root package identity'
    Reset-ContractFixture
    Write-ContractFixture 'apm.yml' ($rootManifest + "`nname: bcgov-crow")
    Assert-ContractError 'root package identity' 'Duplicate full-root package identity'
    Reset-ContractFixture
    Write-ContractFixture 'apm.yml' ($rootManifest.Replace('  - .apm/skills', '  - .apm/skills/../agents'))
    Assert-ContractError 'without traversal' 'Publication traversal injection'

    Write-Host 'Collection compatibility contract tests passed.'
}
finally {
    if (Test-Path -LiteralPath $fixtureRoot) { Remove-Item -LiteralPath $fixtureRoot -Recurse -Force }
}

exit 0
