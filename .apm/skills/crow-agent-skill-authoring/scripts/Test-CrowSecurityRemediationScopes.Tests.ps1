$ErrorActionPreference = 'Stop'
$agentPath = Join-Path $PSScriptRoot '..\..\..\agents\crow-security-remediation.agent.md'
$agentContent = [System.IO.File]::ReadAllText((Resolve-Path -LiteralPath $agentPath).Path)

function Assert-Content {
    param(
        [string]$Content,
        [string]$Expected,
        [string]$Scenario
    )

    $normalizedContent = [regex]::Replace($Content, '\s+', ' ')
    $normalizedExpected = [regex]::Replace($Expected, '\s+', ' ')
    if (-not $normalizedContent.Contains($normalizedExpected)) {
        throw "$Scenario did not contain the expected scope contract: $Expected"
    }
    Write-Information -MessageData "Passed: $Scenario" -InformationAction Continue
}

$expectedMappings = @(
    '| `framework-upgrades`, `frameworks` | `framework-upgrades` |',
    '| `dependencies`, `dependency-updates` | `dependencies` |',
    '| `vulnerability-mitigation` | `vulnerabilities` |',
    '| `code-hardening` | `refactoring` |',
    '| `tests` | `test-coverage` |',
    '| `full` | `all` |'
)
foreach ($mapping in $expectedMappings) {
    Assert-Content `
        -Content $agentContent `
        -Expected $mapping `
        -Scenario 'Preserves a requested scope alias mapping'
}

Assert-Content `
    -Content $agentContent `
    -Expected 'use only canonical `targetScope` for every gate, queue, completion path, and reported scope' `
    -Scenario 'Uses canonical scope after one-time normalization'
Assert-Content `
    -Content $agentContent `
    -Expected '*Skip this step unless canonical `targetScope` is `framework-upgrades` or `all`.*' `
    -Scenario 'Gates framework updates on canonical scope'
Assert-Content `
    -Content $agentContent `
    -Expected '*Skip this step unless canonical `targetScope` is `vulnerabilities` or `all`.*' `
    -Scenario 'Gates vulnerability remediation on canonical scope'
Assert-Content `
    -Content $agentContent `
    -Expected '*Skip this step unless canonical `targetScope` is `dependencies` or `all`.*' `
    -Scenario 'Gates dependency updates on canonical scope'
Assert-Content `
    -Content $agentContent `
    -Expected 'When canonical `targetScope` is `framework-upgrades` or `dependencies`' `
    -Scenario 'Applies the update-only review exemption to canonical scope'

$expectedSkipLines = @(
    '*Skip this step unless canonical `targetScope` is `framework-upgrades` or `all`.*',
    '*Skip this step unless canonical `targetScope` is `vulnerabilities` or `all`.*',
    '*Skip this step unless canonical `targetScope` is `dependencies` or `all`.*',
    '*Skip this step unless canonical `targetScope` is `refactoring` or `all`.*',
    '*Skip this step unless canonical `targetScope` is `test-coverage` or `all`.*'
)
foreach ($skipLine in $expectedSkipLines) {
    Assert-Content `
        -Content $agentContent `
        -Expected $skipLine `
        -Scenario 'Uses canonical scope for a workflow gate'
}

$nonCanonicalSkipLines = @(
    $agentContent -split '\r?\n' |
        Where-Object {
            $_ -match '^\*Skip this step' -and
            $_ -notmatch 'canonical `targetScope`'
        }
)
if ($nonCanonicalSkipLines.Count -gt 0) {
    throw "A workflow gate bypasses canonical scope normalization: $($nonCanonicalSkipLines -join ' | ')"
}

exit 0
