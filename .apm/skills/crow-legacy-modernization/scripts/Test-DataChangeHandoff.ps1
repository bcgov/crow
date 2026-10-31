[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Path,
    [string]$RepoRoot = (Get-Location).Path,
    [string]$CurrentRevision,
    [switch]$RequireSignedOff,
    [switch]$AcceptRevisionMismatch
)

# Exit codes: 0 valid, 1 validation errors, 2 handoff file or repository root missing.
$ErrorActionPreference = 'Stop'
$errors = [System.Collections.Generic.List[string]]::new()
$confidenceValues = @('Verified', 'Inferred', 'Unknown')
$openItemClasses = @('Blocking', 'Advisory', 'Deferred')
$utcTimestampPattern = '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d+)?Z$'
$referencedPaths = [System.Collections.Generic.List[string]]::new()

function Add-HandoffError {
    param([string]$Message)
    $errors.Add($Message)
}

function Get-Prop {
    param($Object, [string]$Name)
    if ($null -eq $Object -or $Object -isnot [pscustomobject]) {
        return $null
    }
    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property) {
        return $null
    }
    # Keep arrays intact so callers can distinguish arrays from scalars.
    return , $property.Value
}

function Test-Text {
    param($Value)
    return ($Value -is [string]) -and -not [string]::IsNullOrWhiteSpace($Value)
}

function Test-UtcTimestamp {
    param($Value)
    # PowerShell 7 converts ISO strings to DateTime; only a 'Z' suffix yields Kind Utc.
    if ($Value -is [datetime]) {
        return $Value.Kind -eq [System.DateTimeKind]::Utc
    }
    $parsed = [datetime]::MinValue
    return (Test-Text $Value) -and $Value -match $utcTimestampPattern -and
        [datetime]::TryParse($Value, [System.Globalization.CultureInfo]::InvariantCulture,
            [System.Globalization.DateTimeStyles]::AdjustToUniversal, [ref]$parsed)
}

function Invoke-Git {
    param([string[]]$Arguments)
    # Windows PowerShell 5.1 turns native stderr into a terminating error under 'Stop'.
    $previousPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $output = @(& git -C $RepoRoot @Arguments 2>$null)
        $exitCode = $LASTEXITCODE
    }
    catch {
        $output = @()
        $exitCode = -1
    }
    finally {
        $ErrorActionPreference = $previousPreference
    }
    return [pscustomobject]@{ ExitCode = $exitCode; Output = $output }
}

function Get-RevisionDrift {
    param([string]$Source, [string]$Current)
    # Returns $null when $Current descends from $Source without changing any
    # referenced file; otherwise a reason. The handoff file itself is never
    # referenced, so committing or signing it off does not count as drift.
    $ancestor = Invoke-Git @('merge-base', '--is-ancestor', $Source, $Current)
    if ($ancestor.ExitCode -eq 1) {
        return 'it is not an ancestor of the current revision'
    }
    if ($ancestor.ExitCode -ne 0) {
        return 'the revisions could not be compared in this repository'
    }
    if ($referencedPaths.Count -eq 0) {
        return $null
    }
    $diff = Invoke-Git (@('--literal-pathspecs', 'diff', '--name-only', $Source, $Current, '--') + $referencedPaths.ToArray())
    if ($diff.ExitCode -ne 0) {
        return 'the referenced files could not be compared'
    }
    $changed = @($diff.Output | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    if ($changed.Count -gt 0) {
        return "referenced files changed since then: $($changed -join ', ')"
    }
    return $null
}

function New-IdTable {
    return [System.Collections.Hashtable]::new([System.StringComparer]::Ordinal)
}

function Get-Array {
    param($Object, [string]$Name, [string]$Label, [switch]$NonEmpty)
    $value = Get-Prop $Object $Name
    if ($null -eq $value -or $value -isnot [System.Array]) {
        if ($null -ne $value -or $NonEmpty) {
            Add-HandoffError "$Label must be an array."
        }
        return @()
    }
    if ($NonEmpty -and $value.Count -eq 0) {
        Add-HandoffError "$Label must not be empty."
    }
    return $value
}

function Test-RelativePath {
    param($Value, [string]$Label, [switch]$MustExist)
    if (-not (Test-Text $Value)) {
        Add-HandoffError "$Label must be a non-empty repository-relative path."
        return
    }
    $normalized = $Value.Replace('\', '/')
    if ($normalized -match '[\x00-\x1f]') {
        Add-HandoffError "$Label must not contain control characters."
        return
    }
    if ($normalized.StartsWith('/') -or $normalized -match '^[A-Za-z]:' -or
        $normalized -match '(^|/)\.\.(/|$)' -or $normalized -match '^[A-Za-z][A-Za-z0-9+.-]*://') {
        Add-HandoffError "$Label '$Value' must be repository-relative without '..'."
        return
    }
    if ($MustExist) {
        try {
            $fullPath = Join-Path $RepoRoot $normalized
            if (-not (Test-Path -LiteralPath $fullPath -PathType Leaf)) {
                Add-HandoffError "$Label '$Value' does not exist under the repository root."
            }
            elseif ((Get-Item -LiteralPath $fullPath).Length -eq 0) {
                Add-HandoffError "$Label '$Value' is empty."
            }
            elseif ($referencedPaths -notcontains $normalized -and
                -not [string]::Equals((Resolve-Path -LiteralPath $fullPath).Path, $handoffFullPath,
                    [System.StringComparison]::OrdinalIgnoreCase)) {
                $referencedPaths.Add($normalized)
            }
        }
        catch {
            Add-HandoffError "$Label '$Value' is not a valid path."
        }
    }
}

function Test-EvidenceRefs {
    param($Object, [string]$Label, [hashtable]$EvidenceIds, [bool]$Required)
    foreach ($ref in (Get-Array $Object 'evidenceRefs' "$Label.evidenceRefs" -NonEmpty:$Required)) {
        if (-not (Test-Text $ref) -or -not $EvidenceIds.ContainsKey($ref)) {
            Add-HandoffError "$Label references unknown evidence '$ref'."
        }
    }
}

function Test-Assessment {
    param($Handoff, [string]$Name, [hashtable]$EvidenceIds, [bool]$SignedOff)
    $section = Get-Prop $Handoff $Name
    if ($section -isnot [pscustomobject]) {
        Add-HandoffError "$Name must be an object."
        return
    }
    if (-not (Test-Text (Get-Prop $section 'summary'))) {
        Add-HandoffError "$Name.summary is required."
    }
    $confidence = Get-Prop $section 'confidence'
    if ($confidenceValues -cnotcontains $confidence) {
        Add-HandoffError "$Name.confidence must be Verified, Inferred, or Unknown."
    }
    elseif ($SignedOff -and $confidence -eq 'Unknown') {
        Add-HandoffError "$Name.confidence cannot be Unknown in a signed-off handoff."
    }
    Test-EvidenceRefs $section $Name $EvidenceIds ($confidence -eq 'Verified')
}

if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
    Write-Host "ERROR: Handoff file not found: $Path"
    exit 2
}
if (-not (Test-Path -LiteralPath $RepoRoot -PathType Container)) {
    Write-Host "ERROR: Repository root not found: $RepoRoot"
    exit 2
}
$RepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path
$handoffFullPath = (Resolve-Path -LiteralPath $Path).Path

try {
    $handoff = [System.IO.File]::ReadAllText((Resolve-Path -LiteralPath $Path).Path) | ConvertFrom-Json
}
catch {
    Write-Host "ERROR: Invalid JSON in ${Path}: $($_.Exception.Message)"
    exit 1
}
if ($handoff -isnot [pscustomobject]) {
    Write-Host 'ERROR: The handoff must be a JSON object.'
    exit 1
}

if ((Get-Prop $handoff 'schemaVersion') -cne '1.0') {
    Add-HandoffError "schemaVersion must be '1.0'."
}
if ((Get-Prop $handoff 'producer') -cne 'crow-legacy-modernization') {
    Add-HandoffError "producer must be 'crow-legacy-modernization'."
}
if ((Get-Prop $handoff 'consumer') -cne 'crow-data-architecture') {
    Add-HandoffError "consumer must be 'crow-data-architecture'."
}

if (-not (Test-UtcTimestamp (Get-Prop $handoff 'generatedAt'))) {
    Add-HandoffError 'generatedAt must be an ISO 8601 UTC timestamp.'
}

if ($RequireSignedOff -and -not (Test-Text $CurrentRevision)) {
    $head = Invoke-Git @('rev-parse', 'HEAD')
    $CurrentRevision = if ($head.ExitCode -eq 0) { "$($head.Output | Select-Object -First 1)" } else { $null }
    if (-not (Test-Text $CurrentRevision)) {
        Add-HandoffError 'CurrentRevision is required when the repository root is not a Git work tree.'
        $CurrentRevision = $null
    }
}
$sourceRevision = Get-Prop $handoff 'sourceRevision'
$sourceRevisionValid = (Test-Text $sourceRevision) -and $sourceRevision -cmatch '^[0-9a-f]{7,64}$'
if (-not $sourceRevisionValid) {
    Add-HandoffError 'sourceRevision must be a lowercase hexadecimal commit identifier.'
}

$status = Get-Prop $handoff 'status'
if (@('draft', 'signed-off') -cnotcontains $status) {
    Add-HandoffError "status must be 'draft' or 'signed-off'."
}
$signedOff = $status -ceq 'signed-off'
if ($RequireSignedOff -and -not $signedOff) {
    Add-HandoffError 'The handoff is not signed off; a draft may be reviewed but not built from.'
}

$scope = Get-Prop $handoff 'scope'
if (-not (Test-Text (Get-Prop $scope 'application'))) {
    Add-HandoffError 'scope.application is required.'
}
Test-RelativePath (Get-Prop $scope 'modernizationPlan') 'scope.modernizationPlan' -MustExist
if (-not (Test-Text (Get-Prop $handoff 'requestedWork'))) {
    Add-HandoffError 'requestedWork is required.'
}

$evidenceIds = New-IdTable
foreach ($item in (Get-Array $handoff 'evidence' 'evidence')) {
    $id = Get-Prop $item 'id'
    if (-not (Test-Text $id) -or $id -cnotmatch '^EV-\d{3,}$') {
        Add-HandoffError "Evidence id '$id' must match EV-NNN."
        continue
    }
    if ($evidenceIds.ContainsKey($id)) {
        Add-HandoffError "Duplicate evidence id '$id'."
    }
    $evidenceIds[$id] = $true
    Test-RelativePath (Get-Prop $item 'path') "evidence $id path" -MustExist
    if (-not (Test-Text (Get-Prop $item 'summary'))) {
        Add-HandoffError "evidence $id summary is required."
    }
    $startLine = Get-Prop $item 'startLine'
    $endLine = Get-Prop $item 'endLine'
    $startIsInteger = ($startLine -is [int]) -or ($startLine -is [long])
    $endIsInteger = ($endLine -is [int]) -or ($endLine -is [long])
    if ($null -ne $startLine -and (-not $startIsInteger -or $startLine -lt 1)) {
        Add-HandoffError "evidence $id startLine must be a positive integer."
    }
    elseif ($null -ne $endLine -and (-not $endIsInteger -or $null -eq $startLine -or $endLine -lt $startLine)) {
        Add-HandoffError "evidence $id endLine must be an integer that does not precede startLine."
    }
}

foreach ($name in @('necessity', 'legacyCompatibility', 'rollback')) {
    Test-Assessment $handoff $name $evidenceIds $signedOff
}

$objectIds = New-IdTable
foreach ($item in (Get-Array $handoff 'affectedObjects' 'affectedObjects' -NonEmpty)) {
    $id = Get-Prop $item 'id'
    if (-not (Test-Text $id) -or $id -cnotmatch '^DO-\d{3,}$') {
        Add-HandoffError "Affected object id '$id' must match DO-NNN."
        continue
    }
    if ($objectIds.ContainsKey($id)) {
        Add-HandoffError "Duplicate affected object id '$id'."
    }
    $objectIds[$id] = $true
    foreach ($field in @('type', 'name', 'change')) {
        if (-not (Test-Text (Get-Prop $item $field))) {
            Add-HandoffError "affected object $id $field is required."
        }
    }
    $confidence = Get-Prop $item 'confidence'
    if ($confidenceValues -cnotcontains $confidence) {
        Add-HandoffError "affected object $id confidence must be Verified, Inferred, or Unknown."
    }
    Test-EvidenceRefs $item "affected object $id" $evidenceIds ($confidence -eq 'Verified')
}

$ownership = Get-Prop $handoff 'ownership'
$dataOwner = Get-Prop $ownership 'dataOwner'
if (-not (Test-Text $dataOwner)) {
    Add-HandoffError 'ownership.dataOwner is required; use Unknown in a draft.'
}
elseif ($signedOff -and $dataOwner -eq 'Unknown') {
    Add-HandoffError 'ownership.dataOwner cannot be Unknown in a signed-off handoff.'
}
$approvals = Get-Array $ownership 'approvals' 'ownership.approvals'
if ($signedOff -and $approvals.Count -eq 0) {
    Add-HandoffError 'ownership.approvals must record at least one approval when signed off.'
}

foreach ($item in (Get-Array $handoff 'testImplications' 'testImplications' -NonEmpty)) {
    if (-not (Test-Text (Get-Prop $item 'id')) -or -not (Test-Text (Get-Prop $item 'summary'))) {
        Add-HandoffError 'Each test implication requires an id and summary.'
    }
}

foreach ($artifactPath in (Get-Array $handoff 'artifactPaths' 'artifactPaths' -NonEmpty)) {
    Test-RelativePath $artifactPath 'artifactPaths entry' -MustExist
}

$blockingCount = 0
$openItemIds = New-IdTable
foreach ($item in (Get-Array $handoff 'openItems' 'openItems')) {
    $id = Get-Prop $item 'id'
    if (-not (Test-Text $id) -or $id -cnotmatch '^OI-\d{3,}$') {
        Add-HandoffError "Open item id '$id' must match OI-NNN."
        continue
    }
    if ($openItemIds.ContainsKey($id)) {
        Add-HandoffError "Duplicate open item id '$id'."
    }
    $openItemIds[$id] = $true
    $class = Get-Prop $item 'class'
    if ($openItemClasses -cnotcontains $class) {
        Add-HandoffError "open item $id class must be Blocking, Advisory, or Deferred."
        continue
    }
    $required = switch ($class) {
        'Blocking' { @('question') }
        'Advisory' { @('owner', 'impact') }
        'Deferred' { @('fallback') }
    }
    foreach ($field in $required) {
        if (-not (Test-Text (Get-Prop $item $field))) {
            Add-HandoffError "$class open item $id requires $field."
        }
    }
    if ($class -eq 'Blocking') {
        $blockingCount++
        foreach ($affected in (Get-Array $item 'affects' "open item $id affects" -NonEmpty)) {
            if (-not (Test-Text $affected) -or -not $objectIds.ContainsKey($affected)) {
                Add-HandoffError "open item $id affects unknown object '$affected'."
            }
        }
    }
}
if ($signedOff -and $blockingCount -gt 0) {
    Add-HandoffError "A signed-off handoff cannot have Blocking open items ($blockingCount found)."
}

$signOff = Get-Prop $handoff 'signOff'
if ($signOff -isnot [pscustomobject]) {
    Add-HandoffError 'signOff must be an object.'
}
elseif ($signedOff) {
    if (-not (Test-Text (Get-Prop $signOff 'approvedBy'))) {
        Add-HandoffError 'signOff.approvedBy is required when signed off.'
    }
    if (-not (Test-UtcTimestamp (Get-Prop $signOff 'approvedAt'))) {
        Add-HandoffError 'signOff.approvedAt must be an ISO 8601 UTC timestamp when signed off.'
    }
}

if ($sourceRevisionValid -and (Test-Text $CurrentRevision)) {
    $current = $CurrentRevision.Trim()
    $prefixLength = [Math]::Min($sourceRevision.Length, $current.Length)
    if ([string]::Compare($sourceRevision, 0, $current, 0, $prefixLength,
            [System.StringComparison]::OrdinalIgnoreCase) -ne 0) {
        $drift = Get-RevisionDrift $sourceRevision $current
        if ($null -eq $drift) {
            Write-Host "Revision check: '$current' descends from sourceRevision '$sourceRevision' with no referenced file changes."
        }
        else {
            $message = "sourceRevision '$sourceRevision' does not match the current revision '$current': $drift."
            if ($AcceptRevisionMismatch) {
                Write-Host "WARNING: $message Accepted by the user."
            }
            else {
                Add-HandoffError $message
            }
        }
    }
}

if ($errors.Count -gt 0) {
    foreach ($message in $errors) {
        Write-Host "ERROR: $message"
    }
    Write-Host "Data-change handoff validation failed: $($errors.Count) error(s)."
    exit 1
}

Write-Host "Data-change handoff validation passed: status $status, $($objectIds.Count) affected object(s)."
exit 0
