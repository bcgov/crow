[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$validator = Join-Path $PSScriptRoot 'Test-HighAvailabilityOutput.ps1'
$template = [System.IO.File]::ReadAllText(
    (Join-Path $PSScriptRoot '..\templates\high-availability-template.md'))
$shell = (Get-Process -Id $PID).Path
$utf8 = [System.Text.UTF8Encoding]::new($false)
$fixtureRoot = Join-Path ([System.IO.Path]::GetTempPath()) (
    'crow-availability-' + [guid]::NewGuid().ToString('N'))
$reportRelative = 'docs/high-availability.md'
$handoffRelative = 'docs/high-availability-crow-testing-handoff.json'
$revision = '0123456789abcdef0123456789abcdef01234567'
$passed = 0

function Write-Fixture {
    param([string]$RelativePath, [string]$Content)
    $target = Join-Path $fixtureRoot $RelativePath
    New-Item -ItemType Directory -Path (Split-Path $target -Parent) -Force | Out-Null
    [System.IO.File]::WriteAllText($target, $Content, $utf8)
}

function Get-FixtureContract {
    return [ordered]@{
        schemaVersion = '1.0'; sourceRevision = $revision; service = 'synthetic-service'
        environment = 'isolated-rehearsal'; platformRevision = 'config-1'
        designStatus = 'draft'; continuityVerdict = 'designed-not-demonstrated'
        lastConfirmed = '2026-11-16'; reviewAfter = '2026-12-16'
        operations = @([ordered]@{ id = 'OP-001'; outcome = 'Submit once and retrieve the saved result.'; owner = 'Application team' })
        scenarios = @([ordered]@{ id = 'SC-001'; change = 'Replace an application version.'; operationIds = @('OP-001'); runbookId = 'RB-001' })
        criteria = @([ordered]@{
            id = 'CR-001'; operationId = 'OP-001'; scenarioId = 'SC-001'
            metric = 'Failed submissions / attempted submissions'; operator = 'lte'
            threshold = 0; unit = 'ratio'; window = 'Each maintenance phase'
            workload = '20 concurrent synthetic users at 10 submissions/second'
            minimumSamples = 100; minimumSeconds = 60
        })
        evidence = @(); results = @()
    }
}

function Write-Report {
    param($Contract)
    $json = $Contract | ConvertTo-Json -Depth 15
    # Match the entire fence independently of platform line endings.
    $pattern = '(?ms)(^```json\r?\n).*?(\r?\n```)'
    $match = [regex]::Match($template, $pattern)
    if (-not $match.Success) { throw 'Report template JSON fence missing.' }
    $content = $template.Substring(0, $match.Index) +
        '```json' + "`n$json`n" + '```' +
        $template.Substring($match.Index + $match.Length)
    $content = [regex]::Replace($content, '\{\{[^}]+\}\}', 'Synthetic reviewed design detail.')
    Write-Fixture $reportRelative $content
}

function Add-Measurement {
    param($Contract)
    $Contract.continuityVerdict = 'demonstrated'
    $Contract.evidence = @([ordered]@{
        id = 'EV-001'; path = 'evidence/synthetic-measurement.json'
        kind = 'supplied-measurement'; confidence = 'Verified'
        environment = $Contract.environment; sourceRevision = $Contract.sourceRevision
        platformRevision = $Contract.platformRevision
        capturedAt = '2026-11-16T10:00:00Z'; reviewAfter = '2026-12-16'
    })
    $Contract.results = @('before', 'during', 'after' | ForEach-Object {
        [ordered]@{
            criterionId = 'CR-001'; evidenceId = 'EV-001'; phase = $_
            observed = 0; unit = 'ratio'; workload = $Contract.criteria[0].workload
            samples = 100; seconds = 60
        }
    })
}

function Invoke-Check {
    param(
        [string]$Name, [int]$Exit = 0, [string]$Text = 'Structural checks',
        [string[]]$Arguments = @(), [string]$RelativePath = $reportRelative
    )
    $previous = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $output = (& $shell -NoProfile -File $validator -RepoRoot $fixtureRoot `
                -Path $RelativePath -AsOf '2026-11-17' @Arguments 2>&1 | Out-String)
        $code = $LASTEXITCODE
    }
    finally { $ErrorActionPreference = $previous }
    if ($code -ne $Exit -or -not $output.Contains($Text)) {
        throw "$Name expected exit $Exit and '$Text', got $code.`n$output"
    }
    $script:passed++
    Write-Output "Passed: $Name"
}

function Invoke-FixtureGit {
    param([string[]]$Arguments)
    $previous = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $output = @(& git -C $fixtureRoot -c user.name=Crow -c user.email=crow@example.invalid `
                -c commit.gpgsign=false @Arguments 2>&1)
        $code = $LASTEXITCODE
    }
    finally { $ErrorActionPreference = $previous }
    if ($code -ne 0) { throw "Fixture git failed: $($output -join "`n")" }
    return ($output | Select-Object -Last 1)
}

function Get-FixtureHandoff {
    param([string]$SourceRevision)
    return [ordered]@{
        schemaVersion = '1.0'; producer = 'crow-high-availability'; consumer = 'crow-testing'
        generatedAt = '2026-11-17T10:00:00Z'; sourceRevision = $SourceRevision
        status = 'signed-off'; reportPath = $reportRelative; scope = 'Synthetic service API criteria'
        requestedWork = [ordered]@{ kind = 'service-tests'; summary = 'Implement the approved API continuity checks.' }
        excludedActions = @('deployment', 'traffic-execution', 'host-os-patching', 'database-engine-patching')
        artifactPaths = @($reportRelative); evidencePaths = @('evidence/synthetic-measurement.json')
        facts = @([ordered]@{
            summary = 'The approved design defines one critical operation.'
            confidence = 'Verified'; evidencePaths = @($reportRelative)
        })
        operationIds = @('OP-001'); scenarioIds = @('SC-001'); criterionIds = @('CR-001')
        compatibilityConstraints = @('Preserve old/new API compatibility.')
        rollbackLimitations = @('Use the reviewed data-compatible application rollback.')
        openItems = @()
        signOff = [ordered]@{ approvedBy = 'Synthetic design owner'; approvedAt = '2026-11-17T09:00:00Z' }
    }
}

function Write-Handoff {
    param($Handoff)
    Write-Fixture $handoffRelative ($Handoff | ConvertTo-Json -Depth 15)
}

New-Item -ItemType Directory -Path $fixtureRoot | Out-Null
try {
    Write-Fixture 'evidence/synthetic-measurement.json' '{"synthetic":true}'
    Write-Report (Get-FixtureContract)
    Invoke-Check 'design completes without pretending operational proof'
    Invoke-Check 'prewrite checks missing future output safely' -Arguments @('-Phase', 'PreWrite') -RelativePath 'docs/new-service/high-availability.md'
    Invoke-Check 'path traversal fails before write' 1 'Unsafe repository-relative path' @('-Phase', 'PreWrite') '..\outside.md'
    Invoke-Check 'missing input is explicit' 2 'Missing input' -RelativePath 'docs/missing.md'
    Invoke-Check 'prewrite cannot authorize project configuration writes' 1 'declared high-availability' @('-Phase', 'PreWrite') 'crow.config'
    Invoke-Check 'prewrite cannot authorize source writes' 1 'declared high-availability' @('-Phase', 'PreWrite') 'src/Program.cs'
    Invoke-Check 'prewrite cannot target directories' 1 'must not be a directory' @('-Phase', 'PreWrite') 'docs'
    Invoke-Check 'prewrite cannot invent a handoff consumer' 1 'declared high-availability' @('-Phase', 'PreWrite') 'docs/high-availability-unknown-handoff.json'
    $validNarrative = [System.IO.File]::ReadAllText((Join-Path $fixtureRoot $reportRelative))
    Write-Fixture $reportRelative ($validNarrative + "`n" + '${{ secrets.SYNTHETIC_REFERENCE }} and {{ .Values.replicas }} are quoted syntax.')
    Invoke-Check 'pipeline and Helm expressions are not owned template placeholders'

    $contract = Get-FixtureContract
    $contract.continuityVerdict = 'cannot-establish'
    $contract.operations = @(); $contract.scenarios = @(); $contract.criteria = @()
    Write-Report $contract
    Invoke-Check 'honest incomplete assessment is a valid report'
    $contract.designStatus = 'approved'
    Write-Report $contract
    Invoke-Check 'approved remediation design still needs a measurable contract' 1 'must not be empty'
    $contract.continuityVerdict = 'not-assessed'
    Write-Report $contract
    Invoke-Check 'unassessed design cannot be approved' 1 'cannot have a not-assessed'
    $contract = Get-FixtureContract
    $contract.continuityVerdict = 'cannot-establish'
    $contract.criteria = @()
    Write-Report $contract
    Invoke-Check 'negative verdict does not hide declared pairs without criteria' 1 'Missing criterion'
    $contract = Get-FixtureContract
    $contract.continuityVerdict = 'cannot-establish'
    $contract.designStatus = 'approved'
    Write-Report $contract
    Invoke-Check 'approved measurable remediation does not claim continuity'

    foreach ($invalidVersion in @($true, 1)) {
        $contract = Get-FixtureContract
        $contract.schemaVersion = $invalidVersion
        Write-Report $contract
        Invoke-Check "non-string report schema version rejected: $invalidVersion" 1 'Unsupported report schemaVersion'
    }

    $contract = Get-FixtureContract
    $contract.operations += $contract.operations[0]
    Write-Report $contract
    Invoke-Check 'duplicate operations rejected' 1 'Duplicate identifier'
    $contract = Get-FixtureContract
    $contract.criteria[0].operationId = 'op-001'
    Write-Report $contract
    Invoke-Check 'references remain case-sensitive' 1 'unknown identifier'
    $contract = Get-FixtureContract
    $contract.operations += [ordered]@{ id = 'OP-002'; outcome = 'Read a saved item'; owner = 'Application team' }
    $contract.scenarios[0].operationIds += 'OP-002'
    Write-Report $contract
    Invoke-Check 'every applicable pair needs a criterion' 1 'Missing criterion'
    $contract = Get-FixtureContract
    $contract.criteria[0].threshold = 'zero'
    Write-Report $contract
    Invoke-Check 'qualitative threshold rejected' 1 'numeric non-negative threshold'
    $contract = Get-FixtureContract
    $contract.criteria[0].minimumSamples = 0
    Write-Report $contract
    Invoke-Check 'sample floor required' 1 'positive minimumSamples'

    $contract = Get-FixtureContract
    Add-Measurement $contract
    Write-Report $contract
    Invoke-Check 'bounded demonstrated record with all phases passes'
    foreach ($field in @('unit', 'workload')) {
        $original = $contract.results[1][$field]
        $contract.results[1][$field] = $true
        Write-Report $contract
        Invoke-Check "boolean result $field cannot coerce to matching text" 1 'unit/workload must match'
        $contract.results[1][$field] = $original
    }
    $contract.results[1].observed = 0.01
    Write-Report $contract
    Invoke-Check 'failed business continuity prevents demonstrated verdict' 1 'fails threshold'
    $contract.continuityVerdict = 'cannot-establish'
    Write-Report $contract
    Invoke-Check 'failed measurements remain reportable without success claim'
    $contract = Get-FixtureContract
    Add-Measurement $contract
    $contract.results = @($contract.results[0], $contract.results[2])
    Write-Report $contract
    Invoke-Check 'before and after alone cannot demonstrate continuity' 1 'Missing demonstrated result'
    $contract = Get-FixtureContract
    Add-Measurement $contract
    $contract.evidence[0].confidence = 'Inferred'
    Write-Report $contract
    Invoke-Check 'inferred observation cannot demonstrate continuity' 1 'Verified supplied measurements'
    $contract.evidence[0].confidence = 'Verified'
    $contract.evidence[0].platformRevision = 'another-config'
    Write-Report $contract
    Invoke-Check 'platform drift caps demonstrated verdict' 1 'Verified supplied measurements'
    $contract = Get-FixtureContract
    Add-Measurement $contract
    $contract.evidence[0].reviewAfter = '2026-11-16'
    Write-Report $contract
    Invoke-Check 'evidence expiry uses deterministic asof' 1 'Verified supplied measurements'
    $contract = Get-FixtureContract
    Add-Measurement $contract
    $contract.results[1].seconds = 1
    Write-Report $contract
    Invoke-Check 'short observation cannot meet verification contract' 1 'fails threshold'
    $contract = Get-FixtureContract
    Add-Measurement $contract
    $contract.criteria[0].operator = 'gte'; $contract.criteria[0].threshold = 1
    foreach ($result in $contract.results) { $result.observed = 1 }
    Write-Report $contract
    Invoke-Check 'minimum threshold comparator is honored'
    $contract.criteria[0].operator = 'eq'; $contract.results[1].observed = 2
    Write-Report $contract
    Invoke-Check 'equality comparator rejects a different outcome' 1 'fails threshold'
    $contract = Get-FixtureContract
    Add-Measurement $contract
    $contract.evidence[0].capturedAt = '2026-11-17T23:30:00Z'
    $contract.evidence[0].reviewAfter = '2026-11-17'
    Write-Report $contract
    $previousZone = [Environment]::GetEnvironmentVariable('TZ', 'Process')
    try {
        [Environment]::SetEnvironmentVariable('TZ', 'Pacific/Kiritimati', 'Process')
        Invoke-Check 'same UTC capture and expiry date is valid across local day boundaries'
    }
    finally { [Environment]::SetEnvironmentVariable('TZ', $previousZone, 'Process') }

    $contract = Get-FixtureContract
    $contract.designStatus = 'approved'
    Write-Report $contract
    Invoke-FixtureGit @('init', '-q') | Out-Null
    Invoke-FixtureGit @('add', '.') | Out-Null
    Invoke-FixtureGit @('commit', '-q', '-m', 'Synthetic approved design') | Out-Null
    $source = Invoke-FixtureGit @('rev-parse', 'HEAD')
    $handoff = Get-FixtureHandoff $source
    Write-Handoff $handoff
    $gate = @('-Phase', 'Handoff', '-RequireSignedOff', '-ExpectedConsumer', 'crow-testing')
    Invoke-Check 'signed-off untested design can hand off implementation' -Arguments $gate -RelativePath $handoffRelative
    foreach ($field in @('schemaVersion', 'producer')) {
        $handoff = Get-FixtureHandoff $source
        $handoff[$field] = $true
        Write-Handoff $handoff
        Invoke-Check "boolean handoff $field cannot pass string schema identity" 1 'Invalid handoff schemaVersion/producer' $gate $handoffRelative
    }
    $handoff = Get-FixtureHandoff $source
    $handoff.requestedWork.kind = $true
    Write-Handoff $handoff
    Invoke-Check 'boolean work kind cannot bypass owner boundary' 1 'requestedWork.kind must be non-empty text' $gate $handoffRelative
    $handoff = Get-FixtureHandoff $source
    $handoff.status = 'draft'
    Write-Handoff $handoff
    Invoke-Check 'draft cannot build' 1 'not signed off' $gate $handoffRelative
    $handoff = Get-FixtureHandoff $source
    $handoff.openItems = @([ordered]@{ class = 'Blocking'; summary = 'Unknown expected behavior'; owner = 'Design owner' })
    Write-Handoff $handoff
    Invoke-Check 'blocking design omission prevents signoff' 1 'Blocking item' $gate $handoffRelative
    $handoff = Get-FixtureHandoff $source
    $handoff.requestedWork.kind = 'deployment'
    Write-Handoff $handoff
    Invoke-Check 'owner authority cannot expand through work kind' 1 'permitted owner boundary' $gate $handoffRelative
    $handoff = Get-FixtureHandoff $source
    $handoff.criterionIds = @('CR-999')
    Write-Handoff $handoff
    Invoke-Check 'handoff cannot invent criteria' 1 'unknown ID' $gate $handoffRelative
    $expandedContract = Get-FixtureContract
    $expandedContract.designStatus = 'approved'
    $expandedContract.operations += [ordered]@{ id = 'OP-002'; outcome = 'Read the saved result'; owner = 'Application team' }
    $expandedContract.scenarios += [ordered]@{ id = 'SC-002'; change = 'Replace another version'; operationIds = @('OP-002'); runbookId = 'RB-001' }
    $additionalCriterion = (Get-FixtureContract).criteria[0]
    $additionalCriterion.id = 'CR-002'
    $additionalCriterion.operationId = 'OP-002'
    $additionalCriterion.scenarioId = 'SC-002'
    $expandedContract.criteria += $additionalCriterion
    Write-Report $expandedContract
    $handoff = Get-FixtureHandoff $source
    $handoff.criterionIds = @('CR-002')
    Write-Handoff $handoff
    Invoke-Check 'known but disconnected handoff criteria rejected' 1 'must belong to its scoped operations' $gate $handoffRelative
    Write-Report $contract
    $handoff = Get-FixtureHandoff $source
    $handoff.signOff.approvedAt = $null
    Write-Handoff $handoff
    Invoke-Check 'explicit signoff evidence required' 1 'approvedBy/approvedAt' $gate $handoffRelative
    $handoff = Get-FixtureHandoff $source
    Write-Handoff $handoff
    Invoke-Check 'wrong consumer cannot implement' 1 'matching ExpectedConsumer' @('-Phase', 'Handoff', '-RequireSignedOff', '-ExpectedConsumer', 'crow-ci-pipelines') $handoffRelative
    Write-Fixture 'evidence/synthetic-measurement.json' '{"synthetic":"changed"}'
    Invoke-Check 'working tree evidence drift rejected' 1 'revision drift' $gate $handoffRelative
    Invoke-Check 'recorded user acceptance can permit revision difference' -Arguments ($gate + '-AcceptRevisionMismatch') -RelativePath $handoffRelative
    Invoke-FixtureGit @('add', '.') | Out-Null
    Invoke-FixtureGit @('commit', '-q', '-m', 'Changed evidence') | Out-Null
    Invoke-Check 'committed evidence drift rejected' 1 'revision drift' $gate $handoffRelative

    $handoff = Get-FixtureHandoff (Invoke-FixtureGit @('rev-parse', 'HEAD'))
    $handoff.evidencePaths = @('../outside.json')
    Write-Handoff $handoff
    Invoke-Check 'handoff evidence cannot escape root' 1 'Unsafe repository-relative path' $gate $handoffRelative
    $link = Join-Path $fixtureRoot 'linked-docs'
    $linkType = if ($env:OS -eq 'Windows_NT') { 'Junction' } else { 'SymbolicLink' }
    New-Item -ItemType $linkType -Path $link -Target (Join-Path $fixtureRoot 'docs') | Out-Null
    try {
        Invoke-Check 'prewrite rejects linked parent' 1 'symbolic link or junction' @('-Phase', 'PreWrite') 'linked-docs/new.md'
    }
    finally { [System.IO.Directory]::Delete($link) }
    Write-Output "$passed availability checks passed."
}
finally {
    Remove-Item -LiteralPath $fixtureRoot -Recurse -Force
}
exit 0
