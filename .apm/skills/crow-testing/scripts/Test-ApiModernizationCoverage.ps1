[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$RepoRoot,

    [Parameter(Mandatory)]
    [string]$InventoryPath,

    [Parameter(Mandatory)]
    [string]$ScenarioPath,

    [Parameter(Mandatory)]
    [string]$ResultsPath
)

$ErrorActionPreference = 'Stop'
$errors = [System.Collections.Generic.List[string]]::new()
$inventoryModulePath = Join-Path $PSScriptRoot '..\..\crow-architecture-review\scripts\CrowApiInventory.psm1'

if (-not (Test-Path -LiteralPath $inventoryModulePath -PathType Leaf)) {
    Write-Error "Required API inventory validator is missing: $inventoryModulePath"
    exit 1
}
Import-Module $inventoryModulePath -Force -ErrorAction Stop

try {
    $root = (Resolve-Path -LiteralPath $RepoRoot -ErrorAction Stop).Path
}
catch {
    Write-Error "Repository root does not exist: $RepoRoot"
    exit 1
}

$pathComparison = if ([System.IO.Path]::DirectorySeparatorChar -eq '\') {
    [System.StringComparison]::OrdinalIgnoreCase
}
else {
    [System.StringComparison]::Ordinal
}

function Add-CoverageError {
    param([string]$Message)
    $errors.Add($Message)
}

function Resolve-CoverageInputFile {
    param(
        [string]$Path,
        [string]$Description
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        Add-CoverageError "$Description path cannot be empty."
        return $null
    }
    if ($Path -match '^[A-Za-z][A-Za-z0-9+.-]*://') {
        Add-CoverageError "$Description path must be repository-relative: $Path"
        return $null
    }

    $platformPath = $Path.Replace(
        '\',
        [string][System.IO.Path]::DirectorySeparatorChar).Replace(
        '/',
        [string][System.IO.Path]::DirectorySeparatorChar)
    try {
        $fullPath = if ([System.IO.Path]::IsPathRooted($platformPath)) {
            [System.IO.Path]::GetFullPath($platformPath)
        }
        else {
            [System.IO.Path]::GetFullPath((Join-Path $root $platformPath))
        }
    }
    catch {
        Add-CoverageError "$Description path is invalid: $Path"
        return $null
    }

    $rootPrefix = $root.TrimEnd(
        [System.IO.Path]::DirectorySeparatorChar,
        [System.IO.Path]::AltDirectorySeparatorChar) +
        [System.IO.Path]::DirectorySeparatorChar
    if (-not $fullPath.StartsWith($rootPrefix, $pathComparison)) {
        Add-CoverageError "$Description path resolves outside the repository: $Path"
        return $null
    }

    $candidate = $fullPath
    while (-not [string]::IsNullOrWhiteSpace($candidate)) {
        if (Test-Path -LiteralPath $candidate) {
            $item = Get-Item -LiteralPath $candidate -Force
            if (($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
                Add-CoverageError "$Description path traverses a symbolic link or junction: $($item.FullName)"
                return $null
            }
        }
        if ([string]::Equals($candidate, $root, $pathComparison)) {
            break
        }
        $parent = Split-Path -Parent $candidate
        if ([string]::IsNullOrWhiteSpace($parent) -or $parent.Length -ge $candidate.Length) {
            break
        }
        $candidate = $parent
    }

    if (-not (Test-Path -LiteralPath $fullPath -PathType Leaf)) {
        Add-CoverageError "$Description file does not exist: $Path"
        return $null
    }

    return $fullPath
}

function Read-CoverageJson {
    param(
        [string]$Path,
        [string]$Description
    )

    try {
        $rawContent = [System.IO.File]::ReadAllText($Path)
        $document = $rawContent | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        Add-CoverageError "$Description is invalid JSON: $Path ($($_.Exception.Message))"
        return $null
    }

    if ($null -eq $document -or
        $document -is [System.Array] -or
        $document -isnot [System.Management.Automation.PSCustomObject]) {
        Add-CoverageError "$Description must be a JSON object: $Path"
        return $null
    }

    return [pscustomobject]@{
        RawContent = $rawContent
        Document = $document
    }
}

function Test-CoverageProperty {
    param(
        [object]$Object,
        [string]$Name,
        [string]$Context
    )

    if ($null -eq $Object -or
        $Object -isnot [System.Management.Automation.PSCustomObject] -or
        -not ($Object.PSObject.Properties.Name -contains $Name)) {
        Add-CoverageError "$Context is missing '$Name'."
        return $false
    }

    return $true
}

function Get-CoverageString {
    param(
        [object]$Object,
        [string]$Name,
        [string]$Context
    )

    if (-not (Test-CoverageProperty $Object $Name $Context)) {
        return $null
    }
    $value = $Object.PSObject.Properties[$Name].Value
    if ($value -isnot [string] -or [string]::IsNullOrWhiteSpace([string]$value)) {
        Add-CoverageError "$Context '$Name' must be a non-empty string."
        return $null
    }
    return [string]$value
}

function Test-CoverageTimestamp {
    param(
        [string]$RawContent,
        [string]$Description
    )

    $timestampMatches = [regex]::Matches($RawContent, '"generatedAt"\s*:\s*"([^"]*)"')
    $timestamp = if ($timestampMatches.Count -eq 1) {
        $timestampMatches[0].Groups[1].Value
    }
    else { '' }
    $parsedTimestamp = [DateTimeOffset]::MinValue
    if ($timestamp -notmatch '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?Z$' -or
        -not [DateTimeOffset]::TryParse($timestamp, [ref]$parsedTimestamp)) {
        Add-CoverageError "$Description generatedAt must be an ISO-8601 UTC timestamp ending in Z."
    }
}

$inventoryFullPath = Resolve-CoverageInputFile $InventoryPath 'API inventory'
$scenarioFullPath = Resolve-CoverageInputFile $ScenarioPath 'API scenario manifest'
$resultsFullPath = Resolve-CoverageInputFile $ResultsPath 'API run results'
if ($errors.Count -gt 0) {
    foreach ($validationError in $errors) {
        Write-Error $validationError -ErrorAction Continue
    }
    Write-Output "API modernization coverage: $($errors.Count) error(s)."
    exit 1
}

$inventoryValidation = Test-CrowApiInventory `
    -RepoRoot $root `
    -InventoryPath $inventoryFullPath `
    -RequireComplete
foreach ($validationError in $inventoryValidation.Errors) {
    Add-CoverageError $validationError
}
if ($null -eq $inventoryValidation.Inventory -or $errors.Count -gt 0) {
    foreach ($validationError in $errors) {
        Write-Error $validationError -ErrorAction Continue
    }
    Write-Output "API modernization coverage: $($errors.Count) error(s)."
    exit 1
}

$scenarioDocument = Read-CoverageJson $scenarioFullPath 'API scenario manifest'
$resultsDocument = Read-CoverageJson $resultsFullPath 'API run results'
if ($errors.Count -gt 0 -or
    $null -eq $scenarioDocument -or
    $null -eq $resultsDocument) {
    foreach ($validationError in $errors) {
        Write-Error $validationError -ErrorAction Continue
    }
    Write-Output "API modernization coverage: $($errors.Count) error(s)."
    exit 1
}

$inventory = $inventoryValidation.Inventory
$sourceRevision = [string]$inventory.sourceRevision
$inventorySha256 = (Get-FileHash -LiteralPath $inventoryFullPath -Algorithm SHA256).Hash.ToLowerInvariant()
$scenarioManifestSha256 = (Get-FileHash -LiteralPath $scenarioFullPath -Algorithm SHA256).Hash.ToLowerInvariant()
$scenarios = $scenarioDocument.Document
$results = $resultsDocument.Document

if ((Get-CoverageString $scenarios 'schemaVersion' 'API scenario manifest') -cne '1.0') {
    Add-CoverageError 'API scenario manifest schemaVersion must be 1.0.'
}
if ((Get-CoverageString $results 'schemaVersion' 'API run results') -cne '1.0') {
    Add-CoverageError 'API run results schemaVersion must be 1.0.'
}
if ((Get-CoverageString $scenarios 'inventorySourceRevision' 'API scenario manifest') -cne $sourceRevision) {
    Add-CoverageError 'API scenario manifest inventorySourceRevision does not match the API inventory.'
}
if ((Get-CoverageString $results 'inventorySourceRevision' 'API run results') -cne $sourceRevision) {
    Add-CoverageError 'API run results inventorySourceRevision does not match the API inventory.'
}
foreach ($document in @(
    [pscustomobject]@{
        Name = 'API scenario manifest'
        Value = $scenarios
        ExpectedInventoryHash = $inventorySha256
    },
    [pscustomobject]@{
        Name = 'API run results'
        Value = $results
        ExpectedInventoryHash = $inventorySha256
    }
)) {
    $declaredInventoryHash = Get-CoverageString $document.Value 'inventorySha256' $document.Name
    if ($declaredInventoryHash -notmatch '^[0-9a-f]{64}$' -or
        $declaredInventoryHash -cne $document.ExpectedInventoryHash) {
        Add-CoverageError "$($document.Name) inventorySha256 does not match the exact API inventory file."
    }
}
$declaredScenarioHash = Get-CoverageString $results 'scenarioManifestSha256' 'API run results'
if ($declaredScenarioHash -notmatch '^[0-9a-f]{64}$' -or
    $declaredScenarioHash -cne $scenarioManifestSha256) {
    Add-CoverageError 'API run results scenarioManifestSha256 does not match the exact scenario manifest file.'
}
Test-CoverageTimestamp $resultsDocument.RawContent 'API run results'

$targetPolicy = $scenarios.targetPolicy
if ($null -eq $targetPolicy -or
    $targetPolicy -is [System.Array] -or
    $targetPolicy -isnot [System.Management.Automation.PSCustomObject]) {
    Add-CoverageError 'API scenario manifest targetPolicy must be a JSON object.'
}
else {
    $environment = Get-CoverageString $targetPolicy 'environment' 'API scenario targetPolicy'
    if ($environment -match '(?i)prod(uction)?|live') {
        Add-CoverageError 'API modernization coverage must not target a production or live environment.'
    }
    foreach ($property in @(
        'baselineBaseUrlEnvironmentVariable',
        'candidateBaseUrlEnvironmentVariable'
    )) {
        $environmentVariable = Get-CoverageString $targetPolicy $property 'API scenario targetPolicy'
        if ($environmentVariable -cnotmatch '^[A-Z_][A-Z0-9_]*$') {
            Add-CoverageError "API scenario targetPolicy '$property' must name an environment variable, not contain a URL or secret."
        }
    }
    if ([string]$targetPolicy.baselineBaseUrlEnvironmentVariable -ceq
        [string]$targetPolicy.candidateBaseUrlEnvironmentVariable) {
        Add-CoverageError 'Baseline and candidate base-address environment-variable references must differ.'
    }
}

if (-not (Test-CoverageProperty $scenarios 'scenarios' 'API scenario manifest') -or
    $scenarios.scenarios -isnot [System.Array] -or
    $scenarios.scenarios.Count -eq 0) {
    Add-CoverageError 'API scenario manifest scenarios must be a non-empty JSON array.'
}
if (-not (Test-CoverageProperty $results 'results' 'API run results') -or
    $results.results -isnot [System.Array]) {
    Add-CoverageError 'API run results results must be a JSON array.'
}

$operationById = @{}
$responseCaseById = @{}
$operationCount = 0
foreach ($api in $inventory.apis) {
    foreach ($operation in $api.operations) {
        $operationCount++
        $operationById[[string]$operation.id] = $operation
        foreach ($caseProperty in @('successResponses', 'errorResponses')) {
            $kind = if ($caseProperty -eq 'successResponses') { 'success' } else { 'error' }
            foreach ($responseCase in $operation.$caseProperty) {
                $responseCaseById[[string]$responseCase.id] = [pscustomobject]@{
                    OperationId = [string]$operation.id
                    Kind = $kind
                }
            }
        }
    }
}

$scenarioById = @{}
$coveredResponseCases = [System.Collections.Generic.HashSet[string]]::new(
    [System.StringComparer]::Ordinal)
$scenarioOperations = @{}
if ($scenarios.scenarios -is [System.Array]) {
    foreach ($scenario in $scenarios.scenarios) {
        if ($null -eq $scenario -or
            $scenario -is [System.Array] -or
            $scenario -isnot [System.Management.Automation.PSCustomObject]) {
            Add-CoverageError 'API scenario manifest must contain only JSON objects.'
            continue
        }

        $scenarioId = Get-CoverageString $scenario 'id' 'API scenario'
        $scenarioIdValid = $scenarioId -match '^SCN-[0-9]{3,}$'
        if (-not $scenarioIdValid) {
            Add-CoverageError "API scenario has invalid id '$scenarioId'."
        }
        elseif ($scenarioById.ContainsKey($scenarioId)) {
            Add-CoverageError "API scenario manifest has duplicate id '$scenarioId'."
        }

        $operationId = Get-CoverageString $scenario 'operationId' "Scenario '$scenarioId'"
        $operationKnown = $false
        if (-not [string]::IsNullOrWhiteSpace($operationId)) {
            $operationKnown = $operationById.ContainsKey($operationId)
        }
        if (-not $operationKnown) {
            Add-CoverageError "Scenario '$scenarioId' references unknown operation '$operationId'."
        }
        $responseCaseId = Get-CoverageString $scenario 'responseCaseId' "Scenario '$scenarioId'"
        $kind = Get-CoverageString $scenario 'kind' "Scenario '$scenarioId'"
        if ($kind -notin @('success', 'error')) {
            Add-CoverageError "Scenario '$scenarioId' kind must be success or error."
        }
        $responseCaseKnown = $false
        if (-not [string]::IsNullOrWhiteSpace($responseCaseId)) {
            $responseCaseKnown = $responseCaseById.ContainsKey($responseCaseId)
        }
        if (-not $responseCaseKnown) {
            Add-CoverageError "Scenario '$scenarioId' references unknown response case '$responseCaseId'."
        }
        elseif ($responseCaseById[$responseCaseId].OperationId -cne $operationId -or
            $responseCaseById[$responseCaseId].Kind -cne $kind) {
            Add-CoverageError "Scenario '$scenarioId' response case '$responseCaseId' does not match its operation and kind."
        }
        else {
            $null = $coveredResponseCases.Add($responseCaseId)
        }

        Get-CoverageString $scenario 'description' "Scenario '$scenarioId'" | Out-Null
        $testReference = Get-CoverageString $scenario 'testReference' "Scenario '$scenarioId'"
        Resolve-CoverageInputFile $testReference "Scenario '$scenarioId' test reference" | Out-Null
        $safety = $scenario.safety
        if ($null -eq $safety -or
            $safety -is [System.Array] -or
            $safety -isnot [System.Management.Automation.PSCustomObject]) {
            Add-CoverageError "Scenario '$scenarioId' safety must be a JSON object."
        }
        elseif ($operationKnown) {
            $safetyClass = Get-CoverageString $safety 'classification' "Scenario '$scenarioId' safety"
            $sideEffects = [string]$operationById[$operationId].sideEffects
            if ($sideEffects -eq 'ReadOnly') {
                if ($safetyClass -cne 'ReadOnly') {
                    Add-CoverageError "Read-only operation '$operationId' must use safety classification ReadOnly."
                }
            }
            elseif ($sideEffects -eq 'StateMutating') {
                if ($safetyClass -cne 'IsolatedMutation') {
                    Add-CoverageError "State-mutating operation '$operationId' requires safety classification IsolatedMutation."
                }
                foreach ($property in @('approvalReference', 'isolation', 'cleanup')) {
                    Get-CoverageString $safety $property "Scenario '$scenarioId' safety" | Out-Null
                }
                if (-not [string]::IsNullOrWhiteSpace([string]$safety.approvalReference)) {
                    Resolve-CoverageInputFile `
                        ([string]$safety.approvalReference) `
                        "Scenario '$scenarioId' approval reference" | Out-Null
                }
            }
            else {
                Add-CoverageError "Scenario '$scenarioId' references operation '$operationId' with unknown side effects '$sideEffects'."
            }
        }

        if ($scenarioIdValid) {
            if (-not $scenarioById.ContainsKey($scenarioId)) {
                $scenarioById[$scenarioId] = $scenario
                $scenarioOperations[$scenarioId] = [pscustomobject]@{
                    OperationId = $operationId
                    Kind = $kind
                }
            }
        }
    }
}

foreach ($responseCaseId in $responseCaseById.Keys) {
    if (-not $coveredResponseCases.Contains([string]$responseCaseId)) {
        Add-CoverageError "API response case '$responseCaseId' has no approved scenario."
    }
}

$resultByScenarioId = @{}
if ($results.results -is [System.Array]) {
    foreach ($result in $results.results) {
        if ($null -eq $result -or
            $result -is [System.Array] -or
            $result -isnot [System.Management.Automation.PSCustomObject]) {
            Add-CoverageError 'API run results must contain only JSON objects.'
            continue
        }

        $scenarioId = Get-CoverageString $result 'scenarioId' 'API run result'
        if ([string]::IsNullOrWhiteSpace($scenarioId)) {
            Add-CoverageError 'API run results contain an empty scenario id.'
            continue
        }
        if (-not $scenarioById.ContainsKey($scenarioId)) {
            Add-CoverageError "API run results contain unknown scenario '$scenarioId'."
            continue
        }
        if ($resultByScenarioId.ContainsKey($scenarioId)) {
            Add-CoverageError "API run results contain duplicate scenario '$scenarioId'."
            continue
        }
        $resultByScenarioId[$scenarioId] = $result

        $expectedClass = if ($scenarioOperations[$scenarioId].Kind -eq 'success') {
            'Success'
        }
        else {
            'Error'
        }
        foreach ($side in @('baseline', 'candidate')) {
            $sideResult = $result.$side
            if ($null -eq $sideResult -or
                $sideResult -is [System.Array] -or
                $sideResult -isnot [System.Management.Automation.PSCustomObject]) {
                Add-CoverageError "Scenario '$scenarioId' result '$side' must be a JSON object."
                continue
            }
            if ((Get-CoverageString $sideResult 'transport' "Scenario '$scenarioId' $side result") -cne 'HTTP') {
                Add-CoverageError "Scenario '$scenarioId' $side result must record transport HTTP."
            }
            $requestCount = 0
            if (-not [int]::TryParse([string]$sideResult.requestCount, [ref]$requestCount) -or
                $requestCount -lt 1) {
                Add-CoverageError "Scenario '$scenarioId' $side result must record at least one HTTP request."
            }
            if ((Get-CoverageString $sideResult 'outcome' "Scenario '$scenarioId' $side result") -cne 'Passed') {
                Add-CoverageError "Scenario '$scenarioId' $side result did not pass on $side."
            }
            if ((Get-CoverageString $sideResult 'responseClass' "Scenario '$scenarioId' $side result") -cne $expectedClass) {
                Add-CoverageError "Scenario '$scenarioId' $side result did not observe the expected $expectedClass response class on $side."
            }
        }

        $comparison = $result.comparison
        if ($null -eq $comparison -or
            $comparison -is [System.Array] -or
            $comparison -isnot [System.Management.Automation.PSCustomObject]) {
            Add-CoverageError "Scenario '$scenarioId' comparison must be a JSON object."
        }
        else {
            $verdict = Get-CoverageString $comparison 'verdict' "Scenario '$scenarioId' comparison"
            if ($verdict -eq 'ApprovedDivergence') {
                $decisionReference = Get-CoverageString $comparison 'decisionReference' "Scenario '$scenarioId' comparison"
                if ($decisionReference -notmatch '^DEC-[0-9]{3,}$') {
                    Add-CoverageError "Scenario '$scenarioId' approved divergence requires a decisionReference using DEC-###."
                }
            }
            elseif ($verdict -cne 'Equivalent') {
                Add-CoverageError "Scenario '$scenarioId' comparison verdict '$verdict' is unresolved or unsupported."
            }
        }
    }
}

foreach ($scenarioId in $scenarioById.Keys) {
    if (-not $resultByScenarioId.ContainsKey($scenarioId)) {
        Add-CoverageError "Approved scenario '$scenarioId' has no run result for both implementations."
    }
}

foreach ($validationError in $errors) {
    Write-Error $validationError -ErrorAction Continue
}

$responseCaseCount = $responseCaseById.Count
$coveredScenarioCount = $resultByScenarioId.Count
Write-Output "API modernization coverage: $($errors.Count) error(s); $operationCount operation(s), $responseCaseCount response case(s), $($scenarioById.Count) approved scenario(s), $coveredScenarioCount result(s)."
if ($errors.Count -gt 0) {
    exit 1
}
exit 0
