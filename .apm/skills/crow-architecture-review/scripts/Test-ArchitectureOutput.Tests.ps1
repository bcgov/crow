[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$validatorPath = Join-Path $PSScriptRoot 'Test-ArchitectureOutput.ps1'
$templatePath = Join-Path $PSScriptRoot '..\architecture-template.md'
$powerShellPath = (Get-Process -Id $PID).Path
$utf8 = [System.Text.UTF8Encoding]::new($false)
$fixtureRoot = Join-Path ([System.IO.Path]::GetTempPath()) (
    'crow-architecture-output-' + [guid]::NewGuid().ToString('N'))

function Invoke-ValidatorTest {
    param(
        [string]$Name,
        [string[]]$Arguments,
        [bool]$ShouldPass
    )

    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $commandOutput = @(
            & $powerShellPath -NoProfile -File $validatorPath @Arguments *>&1
        )
        $passed = $LASTEXITCODE -eq 0
    }
    finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }
    if ($passed -ne $ShouldPass) {
        throw "$Name expected pass=$ShouldPass but pass=$passed. Output: $($commandOutput -join ' | ')"
    }
    Write-Host "Passed: $Name"
}

function Write-TestFile {
    param(
        [string]$Path,
        [string]$Content
    )

    $parent = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    [System.IO.File]::WriteAllText($Path, $Content, $utf8)
}

function New-ValidArchitectureDocument {
    $content = [System.IO.File]::ReadAllText((Resolve-Path $templatePath).Path)
    $content = $content.Replace('{{APPLICATION_ACRONYM}}', 'TEST')
    $content = $content.Replace('{{APPLICATION_NAME}}', 'Test Application')
    $content = $content.Replace('YYYY-MM-DD', '2026-08-31')
    $content = $content.Replace('[Confidence: ]', '[Confidence: Unknown]')
    $content = $content.Replace('`[Name]`', 'Core')
    $content = $content.Replace(
        '# Represent the key boundaries / packages using a relative file-tree layout',
        'src/')
    $content = [regex]::Replace(
        $content,
        '\*(Provide|Describe|Document|Identify|List|Use|Reference)\b[^*]+\*',
        'Verified repository evidence.')
    $content = [regex]::Replace(
        $content,
        '`[^`\r\n]+ / [^`\r\n]+`',
        'Unknown')

    $lines = @($content -split '\r?\n')
    for ($lineIndex = 0; $lineIndex -lt $lines.Count; $lineIndex++) {
        if ($lines[$lineIndex] -notmatch '^\|.+\|$') {
            continue
        }
        $cells = @($lines[$lineIndex].Trim('|').Split('|'))
        for ($cellIndex = 0; $cellIndex -lt $cells.Count; $cellIndex++) {
            if ([string]::IsNullOrWhiteSpace($cells[$cellIndex])) {
                $cells[$cellIndex] = ' Unknown '
            }
        }
        $lines[$lineIndex] = '|' + ($cells -join '|') + '|'
    }
    return $lines -join [Environment]::NewLine
}

function New-ValidSecurityHandoff {
    param(
        [string]$ArchitectureDocument,
        [string]$Classification,
        [string]$ServiceName,
        [string]$ServicePath
    )

    return [ordered]@{
        schemaVersion = '1.0'
        generatedAt = '2026-09-29T18:00:00Z'
        sourceRevision = '0123456789abcdef'
        architectureDocument = $ArchitectureDocument
        scope = [ordered]@{
            classification = $Classification
            serviceName = $ServiceName
            servicePath = $ServicePath
        }
        facts = @(
            [ordered]@{
                id = 'AF-001'
                type = 'TrustBoundary'
                name = 'Application boundary'
                summary = 'Synthetic verified boundary.'
                confidence = 'Verified'
                components = @('application')
                evidenceRefs = @('EV-001')
            }
        )
        workflows = @(
            [ordered]@{
                id = 'WF-001'
                name = 'Protected request'
                actor = 'User'
                trigger = 'Request'
                steps = @(
                    [ordered]@{
                        order = 1
                        component = 'application'
                        action = 'Authorize request'
                        boundary = 'Application boundary'
                    }
                )
                controls = [ordered]@{
                    authentication = @('Synthetic authentication')
                    authorization = @('Synthetic authorization')
                    validation = @()
                    audit = @()
                    tests = @()
                }
                failureMode = 'FailClosed'
                evidenceRefs = @('EV-001')
            }
        )
        evidence = @(
            [ordered]@{
                id = 'EV-001'
                path = $ArchitectureDocument
                startLine = 1
                endLine = 1
                summary = 'Synthetic architecture evidence.'
            }
        )
        unknowns = @()
    } | ConvertTo-Json -Depth 20
}

function New-MonorepoFixture {
    param([string]$Root)

    Write-TestFile (Join-Path $Root 'services\orders\package.json') '{}'
    Write-TestFile (Join-Path $Root 'services\orders\Dockerfile') 'FROM scratch'
    $inventoryPath = Join-Path $Root 'inventory.json'
    Write-TestFile $inventoryPath @'
[
  {
    "name": "orders",
    "sourcePath": "services/orders",
    "manifestPath": "services/orders/package.json",
    "deploymentEntryPoint": "services/orders/Dockerfile",
    "outputPath": "docs/orders/architecture.md"
  }
]
'@
    return $inventoryPath
}

try {
    New-Item -ItemType Directory -Path $fixtureRoot | Out-Null

    $singleRoot = Join-Path $fixtureRoot 'single'
    New-Item -ItemType Directory -Path $singleRoot | Out-Null
    Invoke-ValidatorTest 'single-app pre-write' @(
        '-RepoRoot', $singleRoot,
        '-Classification', 'SingleApp',
        '-Phase', 'PreWrite') $true

    Write-TestFile (Join-Path $singleRoot 'docs\architecture.md') (
        New-ValidArchitectureDocument)
    Invoke-ValidatorTest 'single-app post-write' @(
        '-RepoRoot', $singleRoot,
        '-Classification', 'SingleApp',
        '-Phase', 'PostWrite') $true
    Invoke-ValidatorTest 'single-app required handoff missing' @(
        '-RepoRoot', $singleRoot,
        '-Classification', 'SingleApp',
        '-Phase', 'PostWrite',
        '-RequireSecurityHandoff') $false
    Write-TestFile (
        Join-Path $singleRoot 'docs\architecture-security-facts.json') (
        New-ValidSecurityHandoff `
            -ArchitectureDocument 'docs/architecture.md' `
            -Classification 'SingleApp' `
            -ServiceName 'Test Application' `
            -ServicePath '.')
    Invoke-ValidatorTest 'single-app required handoff valid' @(
        '-RepoRoot', $singleRoot,
        '-Classification', 'SingleApp',
        '-Phase', 'PostWrite',
        '-RequireSecurityHandoff') $true
    $singleHandoffPath = Join-Path $singleRoot 'docs\architecture-security-facts.json'
    $validSingleHandoff = New-ValidSecurityHandoff `
        -ArchitectureDocument 'docs/architecture.md' `
        -Classification 'SingleApp' `
        -ServiceName 'Test Application' `
        -ServicePath '.'
    Write-TestFile $singleHandoffPath (
        $validSingleHandoff.Replace(
            '2026-09-29T18:00:00Z',
            '2026-09-29T18:00:00+00:00'))
    Invoke-ValidatorTest 'handoff requires UTC Z timestamp' @(
        '-RepoRoot', $singleRoot,
        '-Classification', 'SingleApp',
        '-Phase', 'PostWrite',
        '-RequireSecurityHandoff') $false

    $invalidControls = $validSingleHandoff | ConvertFrom-Json
    $invalidControls.workflows[0].controls.PSObject.Properties.Remove('tests')
    Write-TestFile $singleHandoffPath (
        $invalidControls | ConvertTo-Json -Depth 20)
    Invoke-ValidatorTest 'handoff requires every control array' @(
        '-RepoRoot', $singleRoot,
        '-Classification', 'SingleApp',
        '-Phase', 'PostWrite',
        '-RequireSecurityHandoff') $false

    $invalidOrder = $validSingleHandoff | ConvertFrom-Json
    $invalidOrder.workflows[0].steps[0].order = 2
    Write-TestFile $singleHandoffPath (
        $invalidOrder | ConvertTo-Json -Depth 20)
    Invoke-ValidatorTest 'handoff requires ordered workflow steps' @(
        '-RepoRoot', $singleRoot,
        '-Classification', 'SingleApp',
        '-Phase', 'PostWrite',
        '-RequireSecurityHandoff') $false
    Write-TestFile $singleHandoffPath $validSingleHandoff

    Write-TestFile (Join-Path $singleRoot 'docs\architecture.md') 'incomplete'
    Invoke-ValidatorTest 'incomplete document rejected' @(
        '-RepoRoot', $singleRoot,
        '-Classification', 'SingleApp',
        '-Phase', 'PostWrite') $false

    $monorepoRoot = Join-Path $fixtureRoot 'monorepo'
    $inventoryPath = New-MonorepoFixture $monorepoRoot
    Invoke-ValidatorTest 'monorepo pre-write' @(
        '-RepoRoot', $monorepoRoot,
        '-Classification', 'Monorepo',
        '-ServiceInventoryPath', $inventoryPath,
        '-Phase', 'PreWrite') $true

    Write-TestFile (Join-Path $monorepoRoot 'docs\orders\architecture.md') (
        New-ValidArchitectureDocument)
    Write-TestFile (Join-Path $monorepoRoot 'docs\architecture-index.md') @'
# Architecture Index

## Services

| Service | Path | Architecture Document | Primary Technology | Status |
| :--- | :--- | :--- | :--- | :--- |
| orders | services/orders | [architecture.md](./orders/architecture.md) | .NET | Active |

## Shared Infrastructure

No shared infrastructure was found.

## Inter-Service Communication

No inter-service communication was found.
'@
    Invoke-ValidatorTest 'monorepo post-write' @(
        '-RepoRoot', $monorepoRoot,
        '-Classification', 'Monorepo',
        '-ServiceInventoryPath', $inventoryPath,
        '-Phase', 'PostWrite') $true
    Write-TestFile (
        Join-Path $monorepoRoot 'docs\orders\architecture-security-facts.json') (
        New-ValidSecurityHandoff `
            -ArchitectureDocument 'docs/orders/architecture.md' `
            -Classification 'Monorepo' `
            -ServiceName 'orders' `
            -ServicePath 'services/orders')
    Invoke-ValidatorTest 'monorepo required handoff valid' @(
        '-RepoRoot', $monorepoRoot,
        '-Classification', 'Monorepo',
        '-ServiceInventoryPath', $inventoryPath,
        '-Phase', 'PostWrite',
        '-RequireSecurityHandoff') $true

    $indexTemplate = [System.IO.File]::ReadAllText(
        (Resolve-Path (Join-Path $PSScriptRoot '..\resources\architecture-index-template.md')).Path)
    $indexTemplate = $indexTemplate.Replace('SERVICE_NAME', 'orders')
    $indexTemplate = $indexTemplate.Replace('SERVICE_SOURCE_PATH', 'services/orders')
    $indexTemplate = $indexTemplate.Replace('PRIMARY_TECHNOLOGY', '.NET')
    $indexTemplate = $indexTemplate.Replace('STATUS', 'Active')
    Write-TestFile (Join-Path $monorepoRoot 'docs\architecture-index.md') $indexTemplate
    Invoke-ValidatorTest 'index instructions rejected' @(
        '-RepoRoot', $monorepoRoot,
        '-Classification', 'Monorepo',
        '-ServiceInventoryPath', $inventoryPath,
        '-Phase', 'PostWrite') $false

    foreach ($invalidOutputPath in @(
        '/docs/orders/architecture.md',
        'DOCS/orders/ARCHITECTURE.MD',
        '../docs/orders/architecture.md'
    )) {
        $invalidInventory = [System.IO.File]::ReadAllText($inventoryPath)
        $invalidInventory = $invalidInventory.Replace(
            'docs/orders/architecture.md',
            $invalidOutputPath)
        Write-TestFile $inventoryPath $invalidInventory
        Invoke-ValidatorTest "invalid path rejected: $invalidOutputPath" @(
            '-RepoRoot', $monorepoRoot,
            '-Classification', 'Monorepo',
            '-ServiceInventoryPath', $inventoryPath,
            '-Phase', 'PreWrite') $false
        $invalidInventory = $invalidInventory.Replace(
            $invalidOutputPath,
            'docs/orders/architecture.md')
        Write-TestFile $inventoryPath $invalidInventory
    }

    $outsideSourceInventory = [System.IO.File]::ReadAllText($inventoryPath)
    $outsideSourceInventory = $outsideSourceInventory.Replace(
        '"sourcePath": "services/orders"',
        '"sourcePath": "../outside"')
    Write-TestFile $inventoryPath $outsideSourceInventory
    Invoke-ValidatorTest 'source path containment enforced' @(
        '-RepoRoot', $monorepoRoot,
        '-Classification', 'Monorepo',
        '-ServiceInventoryPath', $inventoryPath,
        '-Phase', 'PreWrite') $false
    $outsideSourceInventory = $outsideSourceInventory.Replace(
        '"sourcePath": "../outside"',
        '"sourcePath": "services/orders"')
    Write-TestFile $inventoryPath $outsideSourceInventory

    $linkRoot = Join-Path $fixtureRoot 'link'
    $linkInventory = New-MonorepoFixture $linkRoot
    $outsidePath = Join-Path $fixtureRoot 'outside'
    New-Item -ItemType Directory -Path $outsidePath | Out-Null
    $linkPath = Join-Path $linkRoot 'docs\orders'
    New-Item -ItemType Directory -Path (Split-Path -Parent $linkPath) -Force | Out-Null
    $linkType = if ([System.IO.Path]::DirectorySeparatorChar -eq '\') {
        'Junction'
    }
    else {
        'SymbolicLink'
    }
    try {
        New-Item -ItemType $linkType -Path $linkPath -Target $outsidePath |
            Out-Null
        Invoke-ValidatorTest "$linkType output rejected" @(
            '-RepoRoot', $linkRoot,
            '-Classification', 'Monorepo',
            '-ServiceInventoryPath', $linkInventory,
            '-Phase', 'PreWrite') $false
    }
    catch {
        throw "Unable to create required $linkType test fixture: $($_.Exception.Message)"
    }
}
finally {
    if (Test-Path -LiteralPath $fixtureRoot) {
        Remove-Item -LiteralPath $fixtureRoot -Recurse -Force
    }
}

Write-Host 'Architecture output validator tests passed.'
exit 0
