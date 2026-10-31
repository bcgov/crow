[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$validatorPath = Join-Path $PSScriptRoot 'Test-DataChangeHandoff.ps1'
$templatePath = Join-Path (Split-Path $PSScriptRoot -Parent) 'resources/data-change-handoff-template.json'
$powerShellPath = (Get-Process -Id $PID).Path
$utf8 = [System.Text.UTF8Encoding]::new($false)
$fixtureRoot = Join-Path ([System.IO.Path]::GetTempPath()) (
    'crow-data-change-handoff-' + [guid]::NewGuid().ToString('N'))
$revision = '0123456789abcdef0123456789abcdef01234567'

function New-Handoff {
    param([string]$Status = 'draft')

    $handoff = [ordered]@{
        schemaVersion = '1.0'
        producer = 'crow-legacy-modernization'
        consumer = 'crow-data-architecture'
        generatedAt = '2025-01-15T10:30:00Z'
        sourceRevision = $revision
        status = $Status
        scope = [ordered]@{ application = 'Synthetic permits'; modernizationPlan = 'docs/modernization/plan.md' }
        requestedWork = 'Design the permit status column change.'
        necessity = [ordered]@{ summary = 'The replacement needs a new status value.'; confidence = 'Verified'; evidenceRefs = @('EV-001') }
        affectedObjects = @([ordered]@{ id = 'DO-001'; type = 'Table'; name = 'PERMIT'; change = 'Widen STATUS_CODE.'; confidence = 'Inferred'; evidenceRefs = @('EV-001') })
        legacyCompatibility = [ordered]@{ summary = 'The legacy reader ignores unknown codes.'; confidence = 'Inferred'; evidenceRefs = @() }
        rollback = [ordered]@{ summary = 'Restore the previous width after data review.'; confidence = 'Inferred'; evidenceRefs = @() }
        ownership = [ordered]@{ dataOwner = 'Unknown'; approvals = @() }
        testImplications = @([ordered]@{ id = 'TI-001'; summary = 'Run status scenarios against both versions.'; scenarioRefs = @() })
        artifactPaths = @('docs/modernization/plan.md')
        evidence = @([ordered]@{ id = 'EV-001'; path = 'src/Permit.cs'; startLine = 10; endLine = 12; summary = 'Status mapping.' })
        openItems = @([ordered]@{ id = 'OI-001'; class = 'Blocking'; question = 'Who approves the change?'; affects = @('DO-001') })
        signOff = [ordered]@{ approvedBy = $null; approvedAt = $null }
    }
    if ($Status -eq 'signed-off') {
        $handoff.ownership.dataOwner = 'Synthetic data owner'
        $handoff.ownership.approvals = @([ordered]@{ approver = 'Synthetic data owner'; scope = 'DO-001'; approvedAt = '2025-01-16T09:00:00Z' })
        $handoff.openItems = @([ordered]@{ id = 'OI-001'; class = 'Advisory'; owner = 'Synthetic owner'; impact = 'Reporting lag.'; dueAt = 'Before cutover' })
        $handoff.signOff = [ordered]@{ approvedBy = 'Synthetic approver'; approvedAt = '2025-01-16T09:00:00Z' }
    }
    return $handoff
}

function Invoke-HandoffTest {
    param(
        [string]$Name,
        [string]$Content,
        [int]$ExpectedExit,
        [string]$ExpectedText,
        [string[]]$ExtraArguments = @(),
        [string]$FilePath,
        [string]$RepoRoot = $fixtureRoot
    )

    if (-not $FilePath) {
        $FilePath = Join-Path $fixtureRoot (([guid]::NewGuid().ToString('N')) + '.json')
        [System.IO.File]::WriteAllText($FilePath, $Content, $utf8)
    }
    $arguments = @('-NoProfile', '-File', $validatorPath, '-Path', $FilePath, '-RepoRoot', $RepoRoot) + $ExtraArguments

    $previousPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $output = (& $powerShellPath @arguments 2>&1 | Out-String)
        $exitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previousPreference
    }
    if ($exitCode -ne $ExpectedExit) {
        throw "$Name expected exit $ExpectedExit but got $exitCode.`n$output"
    }
    if ($ExpectedText -and -not $output.Contains($ExpectedText)) {
        throw "$Name expected output containing '$ExpectedText'.`n$output"
    }
    Write-Host "Passed: $Name"
}

function ConvertTo-HandoffJson($Handoff) {
    return ($Handoff | ConvertTo-Json -Depth 10)
}

function Invoke-FixtureGit {
    param([string[]]$Arguments)
    $previousPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $output = @(& git -C $gitRoot -c user.name=Crow -c user.email=crow@example.invalid -c commit.gpgsign=false @Arguments 2>&1)
        $exitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previousPreference
    }
    if ($exitCode -ne 0) {
        throw "git $($Arguments -join ' ') failed.`n$($output -join "`n")"
    }
    return (@($output | ForEach-Object { "$_" }) | Select-Object -Last 1)
}

function Write-FixtureFile {
    param([string]$RelativePath, [string]$Content)
    $fullPath = Join-Path $gitRoot $RelativePath
    New-Item -ItemType Directory -Path (Split-Path $fullPath -Parent) -Force | Out-Null
    [System.IO.File]::WriteAllText($fullPath, $Content, $utf8)
}

function Save-FixtureCommit {
    param([string]$Message)
    Invoke-FixtureGit @('add', '-A') | Out-Null
    Invoke-FixtureGit @('commit', '-q', '-m', $Message) | Out-Null
    return (Invoke-FixtureGit @('rev-parse', 'HEAD'))
}

function Write-GitHandoff {
    param([string]$SourceRevision)
    $handoff = New-Handoff 'signed-off'
    $handoff.sourceRevision = $SourceRevision
    Write-FixtureFile 'docs/modernization/data-change-handoff.json' (ConvertTo-HandoffJson $handoff)
    return (Join-Path $gitRoot 'docs/modernization/data-change-handoff.json')
}

New-Item -ItemType Directory -Path (Join-Path $fixtureRoot 'docs/modernization') -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $fixtureRoot 'src') -Force | Out-Null
[System.IO.File]::WriteAllText((Join-Path $fixtureRoot 'docs/modernization/plan.md'), "# Modernization plan`n", $utf8)
[System.IO.File]::WriteAllText((Join-Path $fixtureRoot 'src/Permit.cs'), "// Synthetic evidence`n", $utf8)
try {
    Invoke-HandoffTest 'valid draft passes' (ConvertTo-HandoffJson (New-Handoff)) 0 'status draft, 1 affected object(s)'
    Invoke-HandoffTest 'valid signed-off handoff passes the consumer gate' (ConvertTo-HandoffJson (New-Handoff 'signed-off')) 0 'status signed-off' @('-RequireSignedOff', '-CurrentRevision', $revision)
    Invoke-HandoffTest 'template placeholders fail' '' 1 'generatedAt must be an ISO 8601 UTC timestamp' -FilePath $templatePath
    Invoke-HandoffTest 'draft fails the consumer gate' (ConvertTo-HandoffJson (New-Handoff)) 1 'not signed off' @('-RequireSignedOff')

    $handoff = New-Handoff 'signed-off'
    $handoff.openItems = @([ordered]@{ id = 'OI-001'; class = 'Blocking'; question = 'Open?'; affects = @('DO-001') })
    Invoke-HandoffTest 'signed-off with blocking item fails' (ConvertTo-HandoffJson $handoff) 1 'cannot have Blocking open items'

    $handoff = New-Handoff 'signed-off'
    $handoff.rollback.confidence = 'Unknown'
    Invoke-HandoffTest 'signed-off with unknown rollback fails' (ConvertTo-HandoffJson $handoff) 1 'rollback.confidence cannot be Unknown'

    $handoff = New-Handoff 'signed-off'
    $handoff.ownership.dataOwner = 'Unknown'
    $handoff.signOff.approvedBy = $null
    Invoke-HandoffTest 'signed-off without owner or approver fails' (ConvertTo-HandoffJson $handoff) 1 'signOff.approvedBy is required'

    Invoke-HandoffTest 'stale revision fails' (ConvertTo-HandoffJson (New-Handoff)) 1 'does not match the current revision' @('-CurrentRevision', 'fedcba9876543210')
    Invoke-HandoffTest 'user-accepted revision mismatch passes with a warning' (ConvertTo-HandoffJson (New-Handoff)) 0 'Accepted by the user' @('-CurrentRevision', 'fedcba9876543210', '-AcceptRevisionMismatch')
    Invoke-HandoffTest 'abbreviated current revision matches' (ConvertTo-HandoffJson (New-Handoff 'signed-off')) 0 'status signed-off' @('-RequireSignedOff', '-CurrentRevision', '0123456')
    Invoke-HandoffTest 'consumer gate requires a revision outside Git' (ConvertTo-HandoffJson (New-Handoff 'signed-off')) 1 'CurrentRevision is required' @('-RequireSignedOff')

    $handoff = New-Handoff 'signed-off'
    $handoff.ownership.approvals = @()
    Invoke-HandoffTest 'signed-off without approvals fails' (ConvertTo-HandoffJson $handoff) 1 'must record at least one approval'

    $handoff = New-Handoff
    $handoff.generatedAt = '2025-01-15T10:30:00+02:00'
    Invoke-HandoffTest 'offset timestamp fails on every PowerShell version' (ConvertTo-HandoffJson $handoff) 1 'generatedAt must be an ISO 8601 UTC timestamp'

    $handoff = New-Handoff
    $handoff.evidence[0].path = 'src/Missing.cs'
    Invoke-HandoffTest 'missing evidence file fails' (ConvertTo-HandoffJson $handoff) 1 "evidence EV-001 path 'src/Missing.cs' does not exist"

    $handoff = New-Handoff
    $handoff.evidence[0].endLine = 'twelve'
    Invoke-HandoffTest 'non-integer endLine fails' (ConvertTo-HandoffJson $handoff) 1 'endLine must be an integer'

    $handoff = New-Handoff
    $handoff.openItems[0].affects = @('DO-999')
    Invoke-HandoffTest 'open item affecting an unknown object fails' (ConvertTo-HandoffJson $handoff) 1 "affects unknown object 'DO-999'"

    $handoff = New-Handoff
    $handoff.affectedObjects[0].evidenceRefs = @('ev-001')
    Invoke-HandoffTest 'evidence references are case-sensitive' (ConvertTo-HandoffJson $handoff) 1 "unknown evidence 'ev-001'"

    $handoff = New-Handoff
    $handoff.artifactPaths = @('docs/modernization/missing.md')
    Invoke-HandoffTest 'missing artifact fails' (ConvertTo-HandoffJson $handoff) 1 'does not exist under the repository root'

    $handoff = New-Handoff
    $handoff.artifactPaths = @('../outside.md')
    Invoke-HandoffTest 'path traversal fails' (ConvertTo-HandoffJson $handoff) 1 "must be repository-relative without '..'"

    $handoff = New-Handoff
    $handoff.affectedObjects[0].evidenceRefs = @('EV-999')
    Invoke-HandoffTest 'unknown evidence reference fails' (ConvertTo-HandoffJson $handoff) 1 "unknown evidence 'EV-999'"

    $handoff = New-Handoff
    $handoff.necessity.evidenceRefs = @()
    Invoke-HandoffTest 'verified fact without evidence fails' (ConvertTo-HandoffJson $handoff) 1 'necessity.evidenceRefs must not be empty'

    $handoff = New-Handoff
    $handoff.openItems = @([ordered]@{ id = 'OI-001'; class = 'Later'; question = 'x' })
    Invoke-HandoffTest 'unknown open-item class fails' (ConvertTo-HandoffJson $handoff) 1 'class must be Blocking, Advisory, or Deferred'

    $handoff = New-Handoff
    $handoff.openItems = @([ordered]@{ id = 'OI-001'; class = 'Deferred' })
    Invoke-HandoffTest 'deferred item without fallback fails' (ConvertTo-HandoffJson $handoff) 1 'Deferred open item OI-001 requires fallback'

    $handoff = New-Handoff
    $handoff.status = 'confirmed'
    Invoke-HandoffTest 'unknown status fails' (ConvertTo-HandoffJson $handoff) 1 "status must be 'draft' or 'signed-off'"

    $gitRoot = Join-Path $fixtureRoot 'repo'
    New-Item -ItemType Directory -Path $gitRoot -Force | Out-Null
    Invoke-FixtureGit @('init', '-q') | Out-Null
    Write-FixtureFile 'docs/modernization/plan.md' "# Modernization plan`n"
    Write-FixtureFile 'src/Permit.cs' "// Synthetic evidence`n"
    $reviewed = Save-FixtureCommit 'Reviewed sources'
    $handoffPath = Write-GitHandoff $reviewed
    Save-FixtureCommit 'Sign off handoff' | Out-Null
    Invoke-HandoffTest 'committing the signed-off handoff keeps it current' '' 0 'descends from sourceRevision' @('-RequireSignedOff') -FilePath $handoffPath -RepoRoot $gitRoot

    Write-FixtureFile 'README.md' "Unrelated change`n"
    Save-FixtureCommit 'Unrelated change' | Out-Null
    Invoke-HandoffTest 'unrelated commits keep the handoff current' '' 0 'status signed-off' @('-RequireSignedOff') -FilePath $handoffPath -RepoRoot $gitRoot

    Write-FixtureFile 'src/Permit.cs' "// Changed evidence`n"
    $changed = Save-FixtureCommit 'Change evidence'
    Invoke-HandoffTest 'changed evidence makes the handoff stale' '' 1 'referenced files changed since then: src/Permit.cs' @('-RequireSignedOff') -FilePath $handoffPath -RepoRoot $gitRoot
    Invoke-HandoffTest 'user can accept changed evidence' '' 0 'Accepted by the user' @('-RequireSignedOff', '-AcceptRevisionMismatch') -FilePath $handoffPath -RepoRoot $gitRoot

    $handoffPath = Write-GitHandoff $changed
    Save-FixtureCommit 'Refresh handoff' | Out-Null
    Invoke-FixtureGit @('checkout', '-q', '-b', 'other', $reviewed) | Out-Null
    Write-FixtureFile 'README.md' "Other branch`n"
    Save-FixtureCommit 'Other branch' | Out-Null
    $handoffPath = Write-GitHandoff $changed
    Invoke-HandoffTest 'non-ancestor source revision fails' '' 1 'is not an ancestor of the current revision' @('-RequireSignedOff') -FilePath $handoffPath -RepoRoot $gitRoot

    Invoke-HandoffTest 'invalid JSON fails' '{ "schemaVersion": ' 1 'Invalid JSON'
    Invoke-HandoffTest 'missing file exits 2' '' 2 'Handoff file not found' -FilePath (Join-Path $fixtureRoot 'missing.json')
}
finally {
    if (Test-Path -LiteralPath $fixtureRoot) {
        Remove-Item -LiteralPath $fixtureRoot -Recurse -Force
    }
}

Write-Host 'All data-change handoff tests passed.'
exit 0
