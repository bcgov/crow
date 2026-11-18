[CmdletBinding()]
param(
    [string]$RepoRoot = (Get-Location).Path,
    [string]$Path = 'docs/high-availability.md',
    [ValidateSet('PreWrite', 'Report', 'Handoff')]
    [string]$Phase = 'Report',
    [string]$ExpectedConsumer,
    [switch]$RequireSignedOff,
    [switch]$AcceptRevisionMismatch,
    [datetime]$AsOf = [datetime]::UtcNow
)

$ErrorActionPreference = 'Stop'
$issues = [System.Collections.Generic.List[string]]::new()
$references = [System.Collections.Generic.List[string]]::new()
$confidenceValues = @('Verified', 'Inferred', 'Unknown')
$validationOptions = @{
    ExpectedConsumer = $ExpectedConsumer
    RequireSignedOff = $RequireSignedOff
    AcceptRevisionMismatch = $AcceptRevisionMismatch
    AsOf = $AsOf
}
$workKinds = @{
    'crow-data-architecture' = 'data-model-change'
    'crow-ci-pipelines' = 'pipeline-configuration'
    'crow-framework-dependency-update' = 'runtime-dependency-update'
    'crow-testing' = 'service-tests'
    'crow-application-development' = 'application-change'
}

function Add-ValidationIssue {
    param([string]$Message)
    $issues.Add($Message)
}

function Get-PropertyValue {
    param($Object, [string]$Name)
    if ($Object -is [pscustomobject]) {
        $property = $Object.PSObject.Properties[$Name]
        if ($null -ne $property) { return , $property.Value }
    }
    return $null
}

function Test-Text {
    param($Value)
    return $Value -is [string] -and -not [string]::IsNullOrWhiteSpace($Value)
}

function Confirm-Text {
    param($Object, [string[]]$Names, [string]$Label)
    foreach ($name in $Names) {
        if (-not (Test-Text (Get-PropertyValue $Object $name))) {
            Add-ValidationIssue "$Label.$name must be non-empty text."
        }
    }
}

function Get-RecordArray {
    param($Object, [string]$Name, [switch]$NonEmpty)
    $value = Get-PropertyValue $Object $Name
    if ($value -isnot [array]) {
        Add-ValidationIssue "$Name must be an array."
        return
    }
    if ($NonEmpty -and $value.Count -eq 0) {
        Add-ValidationIssue "$Name must not be empty."
    }
    return $value
}

function Test-Number {
    param($Value)
    return ($Value -is [valuetype]) -and $Value -isnot [bool] -and
        $Value -isnot [datetime] -and
        [double]::TryParse([string]$Value, [ref]([double]0)) -and
        -not [double]::IsNaN([double]$Value) -and
        -not [double]::IsInfinity([double]$Value) -and [double]$Value -ge 0
}

function Test-UtcTimestamp {
    param($Value)
    if ($Value -is [datetime]) { return $Value.Kind -eq [DateTimeKind]::Utc }
    $parsed = [datetime]::MinValue
    return (Test-Text $Value) -and $Value -cmatch '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d+)?Z$' -and
        [datetime]::TryParse($Value, [cultureinfo]::InvariantCulture,
            [System.Globalization.DateTimeStyles]::AdjustToUniversal, [ref]$parsed)
}

function Get-ReviewDate {
    param($Value)
    if ($Value -is [datetime]) { return $Value.Date }
    $parsed = [datetime]::MinValue
    if ((Test-Text $Value) -and [datetime]::TryParseExact($Value, 'yyyy-MM-dd',
            [cultureinfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::None, [ref]$parsed)) {
        return $parsed
    }
    Add-ValidationIssue 'Review dates must be real YYYY-MM-DD dates.'
    return $null
}

function Get-SafePath {
    param($RelativePath, [switch]$MustExist)
    if (-not (Test-Text $RelativePath)) {
        Add-ValidationIssue 'A non-empty repository-relative path is required.'
        return $null
    }
    $normalized = $RelativePath.Replace('\', '/')
    if ($normalized.StartsWith('/') -or $normalized -match '[:\x00-\x1f]' -or
        $normalized -match '(^|/)\.\.?(/|$)') {
        Add-ValidationIssue "Unsafe repository-relative path: $RelativePath"
        return $null
    }
    $current = $RepoRoot
    foreach ($segment in $normalized.Split('/')) {
        if ([string]::IsNullOrWhiteSpace($segment)) {
            Add-ValidationIssue "Empty path segment: $RelativePath"
            return $null
        }
        $current = Join-Path $current $segment
        if (Test-Path -LiteralPath $current) {
            if (((Get-Item -LiteralPath $current -Force).Attributes -band
                    [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
                Add-ValidationIssue "Path traverses a symbolic link or junction: $RelativePath"
                return $null
            }
        }
    }
    if ($MustExist) {
        if (-not (Test-Path -LiteralPath $current -PathType Leaf) -or
            (Get-Item -LiteralPath $current).Length -eq 0) {
            Add-ValidationIssue "Referenced file is missing or empty: $RelativePath"
            return $null
        }
        if (-not $references.Contains($normalized)) { $references.Add($normalized) }
    }
    return $current
}

function Get-IdTable {
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseLiteralInitializerForHashtable', '',
        Justification = 'Identifiers require the explicit ordinal case-sensitive comparer.')]
    param([object[]]$Items, [string]$Prefix)
    $table = [System.Collections.Hashtable]::new([StringComparer]::Ordinal)
    foreach ($item in $Items) {
        $id = Get-PropertyValue $item 'id'
        if (-not (Test-Text $id) -or $id -cnotmatch ('^' + $Prefix + '-[0-9]{3,}$')) {
            Add-ValidationIssue "$Prefix records need case-sensitive $Prefix- identifiers."
        }
        elseif ($table.ContainsKey($id)) { Add-ValidationIssue "Duplicate identifier: $id" }
        else { $table.Add($id, $item) }
    }
    return , $table
}

function Confirm-OutputPath {
    param([string]$RelativePath, [string]$Mode)
    $normalized = $RelativePath.Replace('\', '/')
    $leaf = ($normalized -split '/')[-1]
    $handoffNames = @($workKinds.Keys | ForEach-Object { "high-availability-$_-handoff.json" })
    $validName = if ($Mode -eq 'Report') { $leaf -ceq 'high-availability.md' }
        elseif ($Mode -eq 'Handoff') { $handoffNames -ccontains $leaf }
        else { $leaf -ceq 'high-availability.md' -or $handoffNames -ccontains $leaf }
    if (-not $normalized.StartsWith('docs/', [StringComparison]::Ordinal) -or -not $validName) {
        Add-ValidationIssue 'Output must be a declared high-availability report or known-consumer handoff under docs.'
    }
}

function Confirm-Reference {
    param($Id, [hashtable]$Table, [string]$Label)
    if (-not (Test-Text $Id) -or -not $Table.ContainsKey($Id)) {
        Add-ValidationIssue "$Label references an unknown identifier: $Id"
        return $false
    }
    return $true
}

function Read-ContinuityReport {
    param([string]$ReportPath)
    $content = [System.IO.File]::ReadAllText($ReportPath)
    $blocks = [regex]::Matches($content,
        '(?ms)^<!-- crow:continuity-contract -->\r?\n```json\r?\n(.*?)\r?\n```\r?\n<!-- /crow:continuity-contract -->')
    if ($blocks.Count -ne 1) {
        Add-ValidationIssue 'Report needs exactly one marked JSON continuity contract.'
        return $null
    }
    if ($content -cmatch '\{\{[A-Z][A-Z0-9_-]*\}\}') { Add-ValidationIssue 'Unresolved template placeholders.' }
    $narrative = [regex]::Replace($content, '(?ms)^```.*?^```[ \t]*\r?$', '')
    $headings = @('1. Scope and evidence', '2. Continuity contract', '3. Gaps and dependencies',
        '4. Target design and alternatives', '5. Phased recommendations',
        '6. Maintenance and recovery runbooks', '7. Verification plan and supplied results',
        '8. Handoffs and decisions', '9. Open and resolved items')
    foreach ($heading in $headings) {
        if ($narrative -notmatch ('(?m)^## ' + [regex]::Escape($heading) + '[ \t]*\r?$')) {
            Add-ValidationIssue "Missing report section: $heading"
        }
    }
    try { $contract = $blocks[0].Groups[1].Value | ConvertFrom-Json }
    catch {
        Add-ValidationIssue "Invalid continuity JSON: $($_.Exception.Message)"
        return $null
    }
    Confirm-Text $contract @('service', 'environment', 'platformRevision') 'contract'
    if (-not (Test-Text $contract.schemaVersion) -or $contract.schemaVersion -cne '1.0') {
        Add-ValidationIssue 'Unsupported report schemaVersion.'
    }
    if ($contract.sourceRevision -cnotmatch '^([0-9a-f]{40}|[0-9a-f]{64})$') {
        Add-ValidationIssue 'sourceRevision must be a full lowercase commit identifier.'
    }
    if (@('draft', 'approved') -cnotcontains $contract.designStatus) {
        Add-ValidationIssue 'Invalid designStatus.'
    }
    $verdicts = @('not-assessed', 'cannot-establish', 'designed-not-demonstrated', 'demonstrated')
    if ($verdicts -cnotcontains $contract.continuityVerdict) { Add-ValidationIssue 'Invalid continuityVerdict.' }
    $demonstrated = $contract.continuityVerdict -ceq 'demonstrated'
    $designed = $contract.continuityVerdict -cin @('designed-not-demonstrated', 'demonstrated')
    $mustHaveDesign = $contract.designStatus -ceq 'approved' -or $designed
    if ($contract.designStatus -ceq 'approved' -and $contract.continuityVerdict -ceq 'not-assessed') {
        Add-ValidationIssue 'Approved design cannot have a not-assessed continuity verdict.'
    }
    $confirmed = Get-ReviewDate $contract.lastConfirmed
    $expires = Get-ReviewDate $contract.reviewAfter
    if ($null -ne $confirmed -and $null -ne $expires -and
        ($confirmed -gt $validationOptions.AsOf.Date -or $expires -lt $confirmed)) {
        Add-ValidationIssue 'Invalid review date ordering.'
    }
    if (($demonstrated -or $contract.designStatus -ceq 'approved') -and
        $null -ne $expires -and $expires -lt $validationOptions.AsOf.Date) {
        Add-ValidationIssue 'Approved/demonstrated report review has expired.'
    }
    $operations = @(Get-RecordArray $contract 'operations' -NonEmpty:$mustHaveDesign)
    $scenarios = @(Get-RecordArray $contract 'scenarios' -NonEmpty:$mustHaveDesign)
    $criteria = @(Get-RecordArray $contract 'criteria' -NonEmpty:$mustHaveDesign)
    $evidence = @(Get-RecordArray $contract 'evidence')
    $results = @(Get-RecordArray $contract 'results')
    $operationIds = Get-IdTable $operations 'OP'
    $scenarioIds = Get-IdTable $scenarios 'SC'
    $criterionIds = Get-IdTable $criteria 'CR'
    $evidenceIds = Get-IdTable $evidence 'EV'
    foreach ($operation in $operations) { Confirm-Text $operation @('outcome', 'owner') 'operation' }
    foreach ($scenario in $scenarios) {
        Confirm-Text $scenario @('change') 'scenario'
        foreach ($id in @(Get-RecordArray $scenario 'operationIds' -NonEmpty)) {
            Confirm-Reference $id $operationIds 'scenario.operationIds' | Out-Null
        }
        if ($scenario.runbookId -cnotmatch '^RB-[0-9]{3,}$' -or
            $narrative -cnotmatch ('(?m)^### ' + [regex]::Escape([string]$scenario.runbookId) + '[ \t]*\r?$')) {
            Add-ValidationIssue "Missing runbook heading for scenario $($scenario.id)."
        }
    }
    foreach ($criterion in $criteria) {
        Confirm-Reference $criterion.operationId $operationIds 'criterion.operationId' | Out-Null
        if (Confirm-Reference $criterion.scenarioId $scenarioIds 'criterion.scenarioId') {
            if (@($scenarioIds[$criterion.scenarioId].operationIds) -cnotcontains $criterion.operationId) {
                Add-ValidationIssue "Criterion $($criterion.id) is outside scenario applicability."
            }
        }
        Confirm-Text $criterion @('metric', 'unit', 'window', 'workload') 'criterion'
        if (@('lte', 'gte', 'eq') -cnotcontains $criterion.operator -or
            -not (Test-Number $criterion.threshold)) {
            Add-ValidationIssue 'Criteria require a numeric non-negative threshold and valid operator.'
        }
        if (-not (Test-Number $criterion.minimumSamples) -or $criterion.minimumSamples -lt 1 -or
            [math]::Truncate([double]$criterion.minimumSamples) -ne $criterion.minimumSamples -or
            -not (Test-Number $criterion.minimumSeconds) -or $criterion.minimumSeconds -le 0) {
            Add-ValidationIssue 'Criteria require positive minimumSamples (integer) and minimumSeconds.'
        }
    }
    if ($operations.Count -gt 0 -or $scenarios.Count -gt 0) {
        foreach ($operation in $operations) {
            if (@($scenarios | Where-Object { @($_.operationIds) -ccontains $operation.id }).Count -eq 0) {
                Add-ValidationIssue "Operation $($operation.id) has no maintenance scenario."
            }
        }
        foreach ($scenario in $scenarios) {
            foreach ($id in @($scenario.operationIds)) {
                if (@($criteria | Where-Object { $_.scenarioId -ceq $scenario.id -and $_.operationId -ceq $id }).Count -eq 0) {
                    Add-ValidationIssue "Missing criterion for $id / $($scenario.id)."
                }
            }
        }
    }
    foreach ($record in $evidence) {
        Get-SafePath $record.path -MustExist | Out-Null
        if (@('repository', 'supplied-config', 'supplied-measurement') -cnotcontains $record.kind -or
            $confidenceValues -cnotcontains $record.confidence) {
            Add-ValidationIssue 'Invalid evidence kind/confidence.'
        }
        if ($record.kind -cin @('supplied-config', 'supplied-measurement')) {
            Confirm-Text $record @('environment', 'sourceRevision', 'platformRevision') 'evidence'
            if (-not (Test-UtcTimestamp $record.capturedAt)) { Add-ValidationIssue 'Evidence capturedAt must be UTC.' }
            $null = Get-ReviewDate $record.reviewAfter
        }
    }
    $resultKeys = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach ($result in $results) {
        $validCriterion = Confirm-Reference $result.criterionId $criterionIds 'result.criterionId'
        $validEvidence = Confirm-Reference $result.evidenceId $evidenceIds 'result.evidenceId'
        if (@('before', 'during', 'after') -cnotcontains $result.phase -or
            -not $resultKeys.Add("$($result.criterionId):$($result.phase)")) {
            Add-ValidationIssue 'Results require unique criterion/phase pairs and valid phases.'
        }
        foreach ($field in @('observed', 'samples', 'seconds')) {
            if (-not (Test-Number (Get-PropertyValue $result $field))) {
                Add-ValidationIssue "result.$field must be numeric and non-negative."
            }
        }
        if (-not $validCriterion -or -not $validEvidence) { continue }
        $criterion = $criterionIds[$result.criterionId]
        $record = $evidenceIds[$result.evidenceId]
        if (-not (Test-Text $result.unit) -or $result.unit -cne $criterion.unit -or
            -not (Test-Text $result.workload) -or $result.workload -cne $criterion.workload) {
            Add-ValidationIssue 'Result unit/workload must match its criterion.'
        }
        if ($demonstrated) {
            $expiry = Get-ReviewDate $record.reviewAfter
            $capture = if (Test-UtcTimestamp $record.capturedAt) { ([datetime]$record.capturedAt).ToUniversalTime() } else { $null }
            if ($record.kind -cne 'supplied-measurement' -or $record.confidence -cne 'Verified' -or
                $record.environment -cne $contract.environment -or
                $record.sourceRevision -cne $contract.sourceRevision -or
                $record.platformRevision -cne $contract.platformRevision -or
                $null -eq $capture -or $capture.ToUniversalTime().Date -gt $validationOptions.AsOf.Date -or
                $null -eq $expiry -or $expiry -lt $validationOptions.AsOf.Date -or
                ($null -ne $capture -and $null -ne $expiry -and $expiry -lt $capture.Date)) {
                Add-ValidationIssue 'Demonstrated results need current Verified supplied measurements for the assessed environment/revisions.'
            }
            $meets = switch ($criterion.operator) {
                'lte' { $result.observed -le $criterion.threshold }
                'gte' { $result.observed -ge $criterion.threshold }
                'eq' { $result.observed -eq $criterion.threshold }
                default { $false }
            }
            if (-not $meets -or $result.samples -lt $criterion.minimumSamples -or
                $result.seconds -lt $criterion.minimumSeconds) {
                Add-ValidationIssue "Demonstrated result fails threshold/sample/duration: $($criterion.id)."
            }
        }
    }
    if ($demonstrated) {
        foreach ($criterion in $criteria) {
            foreach ($period in @('before', 'during', 'after')) {
                if (-not $resultKeys.Contains("$($criterion.id):$period")) {
                    Add-ValidationIssue "Missing demonstrated result: $($criterion.id) / $period."
                }
            }
        }
    }
    return $contract
}

function Invoke-ReadOnlyGit {
    param([string[]]$Arguments)
    $previous = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $output = @(& git -C $RepoRoot @Arguments 2>&1)
        $code = $LASTEXITCODE
    }
    finally { $ErrorActionPreference = $previous }
    return [pscustomobject]@{ Code = $code; Output = ($output | Out-String).Trim() }
}

function Confirm-HandoffFreshness {
    param([string]$Revision)
    # Keep this bounded to referenced files; the handoff itself is not a source artifact.
    $ancestor = Invoke-ReadOnlyGit @('merge-base', '--is-ancestor', $Revision, 'HEAD')
    $diff = Invoke-ReadOnlyGit (@('--literal-pathspecs', 'diff', '--name-only', $Revision, 'HEAD', '--') + $references.ToArray())
    $status = Invoke-ReadOnlyGit (@('--literal-pathspecs', 'status', '--porcelain', '--untracked-files=all', '--ignored=traditional', '--') + $references.ToArray())
    if ($ancestor.Code -gt 1 -or $diff.Code -ne 0 -or $status.Code -ne 0) {
        Add-ValidationIssue 'Cannot establish handoff revision freshness with Git.'
    }
    elseif ($ancestor.Code -ne 0 -or $diff.Output -or $status.Output) {
        if ($validationOptions.AcceptRevisionMismatch) { Write-Warning 'Revision difference accepted by the user; preserve the recorded acceptance.' }
        else { Add-ValidationIssue 'Handoff revision drift: ancestry or referenced files changed; explicit acceptance required.' }
    }
}

function Confirm-Handoff {
    param([string]$HandoffPath)
    $content = [System.IO.File]::ReadAllText($HandoffPath)
    if ($content -cmatch '\{\{[A-Z][A-Z0-9_-]*\}\}') { Add-ValidationIssue 'Unresolved template placeholders.' }
    try { $handoff = $content | ConvertFrom-Json }
    catch {
        Add-ValidationIssue "Invalid handoff JSON: $($_.Exception.Message)"
        return
    }
    if (-not (Test-Text $handoff.schemaVersion) -or $handoff.schemaVersion -cne '1.0' -or
        -not (Test-Text $handoff.producer) -or $handoff.producer -cne 'crow-high-availability') {
        Add-ValidationIssue 'Invalid handoff schemaVersion/producer.'
    }
    if (-not (Test-Text $handoff.consumer) -or -not $workKinds.ContainsKey([string]$handoff.consumer) -or
        $handoff.requestedWork.kind -cne $workKinds[[string]$handoff.consumer]) {
        Add-ValidationIssue 'Consumer/work kind is outside the permitted owner boundary.'
    }
    $expectedName = "high-availability-$($handoff.consumer)-handoff.json"
    if ([System.IO.Path]::GetFileName($HandoffPath) -cne $expectedName) {
        Add-ValidationIssue 'Handoff filename must identify its consumer.'
    }
    if (($validationOptions.ExpectedConsumer -and $handoff.consumer -cne $validationOptions.ExpectedConsumer) -or
        ($validationOptions.RequireSignedOff -and -not $validationOptions.ExpectedConsumer)) {
        Add-ValidationIssue 'Consumer gate requires the matching ExpectedConsumer.'
    }
    Confirm-Text $handoff @('scope') 'handoff'
    Confirm-Text $handoff.requestedWork @('kind', 'summary') 'requestedWork'
    if (-not (Test-UtcTimestamp $handoff.generatedAt)) { Add-ValidationIssue 'generatedAt must be UTC.' }
    if ($handoff.sourceRevision -cnotmatch '^([0-9a-f]{40}|[0-9a-f]{64})$') {
        Add-ValidationIssue 'sourceRevision must be a full lowercase commit identifier.'
    }
    if (@('draft', 'signed-off') -cnotcontains $handoff.status) { Add-ValidationIssue 'Invalid handoff status.' }
    $signed = $handoff.status -ceq 'signed-off'
    if ($validationOptions.RequireSignedOff -and -not $signed) { Add-ValidationIssue 'Handoff is not signed off; review only.' }
    $excluded = @(Get-RecordArray $handoff 'excludedActions')
    foreach ($action in @('deployment', 'traffic-execution', 'host-os-patching', 'database-engine-patching')) {
        if ($excluded -cnotcontains $action) { Add-ValidationIssue "Missing mandatory exclusion: $action" }
    }
    Confirm-OutputPath ([string]$handoff.reportPath) 'Report'
    $reportPath = Get-SafePath $handoff.reportPath -MustExist
    $contract = if ($null -ne $reportPath) { Read-ContinuityReport $reportPath } else { $null }
    if ($signed -and $null -ne $contract -and $contract.designStatus -cne 'approved') {
        Add-ValidationIssue 'Signed-off handoff requires an approved design, not demonstrated continuity.'
    }
    foreach ($name in @('artifactPaths', 'evidencePaths')) {
        foreach ($item in @(Get-RecordArray $handoff $name -NonEmpty:($name -eq 'artifactPaths'))) {
            Get-SafePath $item -MustExist | Out-Null
        }
    }
    foreach ($name in @('operationIds', 'scenarioIds', 'criterionIds')) {
        $reportName = @{ operationIds = 'operations'; scenarioIds = 'scenarios'; criterionIds = 'criteria' }[$name]
        $known = @((Get-PropertyValue $contract $reportName) | ForEach-Object { $_.id })
        foreach ($id in @(Get-RecordArray $handoff $name -NonEmpty:$signed)) {
            if ($known -cnotcontains $id) { Add-ValidationIssue "Handoff $name references unknown ID: $id" }
        }
    }
    foreach ($criterion in @($contract.criteria | Where-Object { @($handoff.criterionIds) -ccontains $_.id })) {
        if (@($handoff.operationIds) -cnotcontains $criterion.operationId -or
            @($handoff.scenarioIds) -cnotcontains $criterion.scenarioId) {
            Add-ValidationIssue 'Handoff criteria must belong to its scoped operations and scenarios.'
        }
    }
    foreach ($name in @('compatibilityConstraints', 'rollbackLimitations')) {
        foreach ($item in @(Get-RecordArray $handoff $name -NonEmpty)) {
            if (-not (Test-Text $item)) { Add-ValidationIssue "$name must contain non-empty text." }
        }
    }
    foreach ($fact in @(Get-RecordArray $handoff 'facts' -NonEmpty)) {
        Confirm-Text $fact @('summary') 'fact'
        if ($confidenceValues -cnotcontains $fact.confidence -or ($signed -and $fact.confidence -ceq 'Unknown')) {
            Add-ValidationIssue 'Invalid fact confidence; signed-off scoped facts cannot be Unknown.'
        }
        foreach ($item in @(Get-RecordArray $fact 'evidencePaths' -NonEmpty:($fact.confidence -ceq 'Verified'))) {
            Get-SafePath $item -MustExist | Out-Null
        }
    }
    foreach ($item in @(Get-RecordArray $handoff 'openItems')) {
        if (@('Blocking', 'Advisory', 'Deferred') -cnotcontains $item.class -or
            ($signed -and $item.class -ceq 'Blocking')) {
            Add-ValidationIssue 'Invalid open item class or Blocking item in signed-off handoff.'
        }
        Confirm-Text $item @('summary', 'owner') 'openItem'
    }
    if ($signed -and (-not (Test-Text $handoff.signOff.approvedBy) -or
            -not (Test-UtcTimestamp $handoff.signOff.approvedAt))) {
        Add-ValidationIssue 'Signed-off handoff requires explicit approvedBy/approvedAt.'
    }
    $handoffRelative = [System.IO.Path]::GetFullPath($HandoffPath)
    foreach ($reference in $references) {
        $full = Join-Path $RepoRoot ($reference.Replace('/', [System.IO.Path]::DirectorySeparatorChar))
        if ([string]::Equals([System.IO.Path]::GetFullPath($full), $handoffRelative,
                [StringComparison]::OrdinalIgnoreCase)) {
            Add-ValidationIssue 'Handoff cannot reference itself as an artifact or evidence.'
        }
    }
    if ($signed -and $issues.Count -eq 0) { Confirm-HandoffFreshness $handoff.sourceRevision }
}

if (-not (Test-Path -LiteralPath $RepoRoot -PathType Container)) {
    Write-Output "Missing repository root: $RepoRoot"
    exit 2
}
$RepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path
try {
    $fullPath = Get-SafePath $Path
    Confirm-OutputPath $Path $Phase
    if ($null -ne $fullPath -and (Test-Path -LiteralPath $fullPath -PathType Container)) {
        Add-ValidationIssue 'Output path must not be a directory.'
    }
    if ($null -ne $fullPath -and $Phase -ne 'PreWrite') {
        if (-not (Test-Path -LiteralPath $fullPath -PathType Leaf)) {
            Write-Output "Missing input: $Path"
            exit 2
        }
        if ($Phase -eq 'Handoff') { Confirm-Handoff $fullPath }
        else { $null = Read-ContinuityReport $fullPath }
    }
}
catch { Add-ValidationIssue "Validation failed: $($_.Exception.Message)" }
foreach ($issue in $issues) { Write-Output "[ERROR] $issue" }
if ($issues.Count -gt 0) { exit 1 }
Write-Output "Valid $Phase output. Structural checks are not proof of continuity."
exit 0
