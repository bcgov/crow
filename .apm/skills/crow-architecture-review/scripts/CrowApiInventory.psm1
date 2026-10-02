<#
.SYNOPSIS
  Validates the shared REST/SOAP API inventory contract.

.DESCRIPTION
  The architecture-output and API modernization coverage validators use this
  module so inventory IDs, evidence, and completeness rules have one source.
  Importing the module performs no file writes and does not execute inventory
  content.
#>

$script:CrowApiProtocols = @('REST', 'SOAP')
$script:CrowApiContractTypes = @('OpenAPI', 'WSDL', 'XSD', 'Source', 'Documentation', 'Other')
$script:CrowApiConfidence = @('Verified', 'Inferred', 'Unknown')
$script:CrowApiSideEffects = @('ReadOnly', 'StateMutating', 'Unknown')
$script:CrowApiHttpMethods = @('GET', 'HEAD', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS', 'Unknown')

function Add-CrowApiInventoryError {
    param(
        [System.Collections.Generic.List[string]]$Errors,
        [string]$Message
    )

    $Errors.Add($Message)
}

function Test-CrowApiInventoryObject {
    param(
        [object]$Value,
        [string]$Context,
        [System.Collections.Generic.List[string]]$Errors
    )

    if ($null -eq $Value -or
        $Value -is [System.Array] -or
        $Value -isnot [System.Management.Automation.PSCustomObject]) {
        Add-CrowApiInventoryError $Errors "$Context must be a JSON object."
        return $false
    }

    return $true
}

function Get-CrowApiInventoryString {
    param(
        [object]$Object,
        [string]$Name,
        [string]$Context,
        [System.Collections.Generic.List[string]]$Errors,
        [switch]$AllowEmpty
    )

    if ($null -eq $Object -or
        $Object -isnot [System.Management.Automation.PSCustomObject] -or
        -not ($Object.PSObject.Properties.Name -contains $Name)) {
        Add-CrowApiInventoryError $Errors "$Context is missing '$Name'."
        return $null
    }

    $value = $Object.PSObject.Properties[$Name].Value
    if ($value -isnot [string] -or
        (([string]$value).Length -eq 0 -and -not $AllowEmpty) -or
        (([string]$value).Length -gt 0 -and [string]::IsNullOrWhiteSpace([string]$value))) {
        Add-CrowApiInventoryError $Errors "$Context '$Name' must be a non-empty string."
        return $null
    }

    return [string]$value
}

function Test-CrowApiInventoryStringArray {
    param(
        [object]$Object,
        [string]$Name,
        [string]$Context,
        [System.Collections.Generic.List[string]]$Errors,
        [switch]$AllowEmpty
    )

    if ($null -eq $Object -or
        $Object -isnot [System.Management.Automation.PSCustomObject] -or
        -not ($Object.PSObject.Properties.Name -contains $Name)) {
        Add-CrowApiInventoryError $Errors "$Context is missing '$Name' array."
        return $false
    }

    $values = $Object.PSObject.Properties[$Name].Value
    if ($values -isnot [System.Array]) {
        Add-CrowApiInventoryError $Errors "$Context '$Name' must be a JSON array."
        return $false
    }
    if (-not $AllowEmpty -and $values.Count -eq 0) {
        Add-CrowApiInventoryError $Errors "$Context '$Name' cannot be empty."
        return $false
    }

    $valid = $true
    foreach ($value in $values) {
        if ($value -isnot [string] -or [string]::IsNullOrWhiteSpace([string]$value)) {
            Add-CrowApiInventoryError $Errors "$Context '$Name' must contain only non-empty strings."
            $valid = $false
        }
    }

    return $valid
}

function Test-CrowApiInventoryObjectArray {
    param(
        [object]$Object,
        [string]$Name,
        [string]$Context,
        [System.Collections.Generic.List[string]]$Errors,
        [switch]$AllowEmpty
    )

    if ($null -eq $Object -or
        $Object -isnot [System.Management.Automation.PSCustomObject] -or
        -not ($Object.PSObject.Properties.Name -contains $Name)) {
        Add-CrowApiInventoryError $Errors "$Context is missing '$Name' array."
        return $false
    }

    $values = $Object.PSObject.Properties[$Name].Value
    if ($values -isnot [System.Array]) {
        Add-CrowApiInventoryError $Errors "$Context '$Name' must be a JSON array."
        return $false
    }
    if (-not $AllowEmpty -and $values.Count -eq 0) {
        Add-CrowApiInventoryError $Errors "$Context '$Name' cannot be empty."
        return $false
    }

    $valid = $true
    foreach ($value in $values) {
        if ($null -eq $value -or
            $value -is [System.Array] -or
            $value -isnot [System.Management.Automation.PSCustomObject]) {
            Add-CrowApiInventoryError $Errors "$Context '$Name' must contain only JSON objects."
            $valid = $false
        }
    }

    return $valid
}

function Test-CrowApiInventoryEvidenceReference {
    param(
        [object]$Object,
        [string]$Name,
        [string]$Context,
        [System.Collections.Generic.HashSet[string]]$EvidenceIds,
        [System.Collections.Generic.List[string]]$Errors,
        [switch]$AllowEmpty
    )

    if (-not (Test-CrowApiInventoryStringArray `
        -Object $Object `
        -Name $Name `
        -Context $Context `
        -Errors $Errors `
        -AllowEmpty:$AllowEmpty)) {
        return
    }

    foreach ($reference in @($Object.PSObject.Properties[$Name].Value)) {
        if (-not $EvidenceIds.Contains([string]$reference)) {
            Add-CrowApiInventoryError $Errors "$Context references unknown evidence '$reference'."
        }
    }
}

function Resolve-CrowApiInventoryPath {
    param(
        [string]$Root,
        [string]$RelativePath,
        [string]$Context,
        [System.Collections.Generic.List[string]]$Errors,
        [switch]$RequireFile,
        [switch]$RequireDirectory,
        [switch]$AllowAbsolute
    )

    if ([string]::IsNullOrWhiteSpace($RelativePath) -or
        ([System.IO.Path]::IsPathRooted($RelativePath) -and -not $AllowAbsolute) -or
        $RelativePath -match '^[A-Za-z][A-Za-z0-9+.-]*://') {
        Add-CrowApiInventoryError $Errors "$Context must be a repository-relative path: $RelativePath"
        return $null
    }

    $platformPath = $RelativePath.Replace(
        '\',
        [string][System.IO.Path]::DirectorySeparatorChar).Replace(
        '/',
        [string][System.IO.Path]::DirectorySeparatorChar)
    try {
        $resolved = if ([System.IO.Path]::IsPathRooted($platformPath)) {
            [System.IO.Path]::GetFullPath($platformPath)
        }
        else {
            [System.IO.Path]::GetFullPath((Join-Path $Root $platformPath))
        }
    }
    catch {
        Add-CrowApiInventoryError $Errors "$Context is not a valid repository path: $RelativePath"
        return $null
    }

    $rootPrefix = $Root.TrimEnd(
        [System.IO.Path]::DirectorySeparatorChar,
        [System.IO.Path]::AltDirectorySeparatorChar) +
        [System.IO.Path]::DirectorySeparatorChar
    $comparison = if ([System.IO.Path]::DirectorySeparatorChar -eq '\') {
        [System.StringComparison]::OrdinalIgnoreCase
    }
    else {
        [System.StringComparison]::Ordinal
    }
    if (-not $resolved.StartsWith($rootPrefix, $comparison)) {
        Add-CrowApiInventoryError $Errors "$Context resolves outside the repository: $RelativePath"
        return $null
    }

    $candidate = $resolved
    while (-not [string]::IsNullOrWhiteSpace($candidate)) {
        if (Test-Path -LiteralPath $candidate) {
            $item = Get-Item -LiteralPath $candidate -Force
            if (($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
                Add-CrowApiInventoryError $Errors "$Context traverses a symbolic link or junction: $($item.FullName)"
                return $null
            }
        }
        if ([string]::Equals($candidate, $Root, $comparison)) {
            break
        }
        $parent = Split-Path -Parent $candidate
        if ([string]::IsNullOrWhiteSpace($parent) -or $parent.Length -ge $candidate.Length) {
            break
        }
        $candidate = $parent
    }

    if ($RequireFile -and -not (Test-Path -LiteralPath $resolved -PathType Leaf)) {
        Add-CrowApiInventoryError $Errors "$Context does not exist: $RelativePath"
        return $null
    }
    if ($RequireDirectory -and -not (Test-Path -LiteralPath $resolved -PathType Container)) {
        Add-CrowApiInventoryError $Errors "$Context does not exist: $RelativePath"
        return $null
    }

    return $resolved
}

function Test-CrowApiInventory {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$RepoRoot,

        [Parameter(Mandatory)]
        [string]$InventoryPath,

        [ValidateSet('SingleApp', 'Monorepo')]
        [string]$ExpectedClassification,

        [string]$ExpectedServiceName,

        [string]$ExpectedServicePath,

        [switch]$RequireComplete
    )

    $errors = [System.Collections.Generic.List[string]]::new()
    $inventory = $null
    try {
        $root = (Resolve-Path -LiteralPath $RepoRoot -ErrorAction Stop).Path
    }
    catch {
        Add-CrowApiInventoryError $errors "Repository root does not exist: $RepoRoot"
        return [pscustomobject]@{
            IsValid = $false
            Errors = @($errors)
            Inventory = $null
        }
    }

    $inventoryFullPath = Resolve-CrowApiInventoryPath `
        -Root $root `
        -RelativePath $InventoryPath `
        -Context 'API inventory' `
        -Errors $errors `
        -AllowAbsolute `
        -RequireFile
    if ($null -eq $inventoryFullPath) {
        return [pscustomobject]@{
            IsValid = $false
            Errors = @($errors)
            Inventory = $null
        }
    }

    try {
        $rawContent = [System.IO.File]::ReadAllText($inventoryFullPath)
        $inventory = $rawContent | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        Add-CrowApiInventoryError $errors "API inventory is invalid JSON: $inventoryFullPath ($($_.Exception.Message))"
        return [pscustomobject]@{
            IsValid = $false
            Errors = @($errors)
            Inventory = $null
        }
    }

    if (-not (Test-CrowApiInventoryObject $inventory 'API inventory' $errors)) {
        return [pscustomobject]@{
            IsValid = $false
            Errors = @($errors)
            Inventory = $inventory
        }
    }

    if ((Get-CrowApiInventoryString $inventory 'schemaVersion' 'API inventory' $errors) -cne '1.0') {
        Add-CrowApiInventoryError $errors 'API inventory schemaVersion must be 1.0.'
    }
    if ((Get-CrowApiInventoryString $inventory 'sourceRevision' 'API inventory' $errors) -notmatch '^[0-9a-f]{7,40}$') {
        Add-CrowApiInventoryError $errors 'API inventory sourceRevision must be a Git SHA with 7 to 40 lowercase hexadecimal characters.'
    }

    $timestampMatches = [regex]::Matches(
        $rawContent, '"generatedAt"\s*:\s*"([^"]*)"')
    $timestamp = if ($timestampMatches.Count -eq 1) {
        $timestampMatches[0].Groups[1].Value
    }
    else { '' }
    $generatedAt = [DateTimeOffset]::MinValue
    if ($timestamp -notmatch '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?Z$' -or
        -not [DateTimeOffset]::TryParse($timestamp, [ref]$generatedAt)) {
        Add-CrowApiInventoryError $errors 'API inventory generatedAt must be an ISO-8601 UTC timestamp ending in Z.'
    }

    $scope = $inventory.scope
    if (-not (Test-CrowApiInventoryObject $scope 'API inventory scope' $errors)) {
        $scope = $null
    }
    else {
        $classification = Get-CrowApiInventoryString $scope 'classification' 'API inventory scope' $errors
        $serviceName = Get-CrowApiInventoryString $scope 'serviceName' 'API inventory scope' $errors
        $servicePath = Get-CrowApiInventoryString $scope 'servicePath' 'API inventory scope' $errors

        if ($classification -notin @('SingleApp', 'Monorepo')) {
            Add-CrowApiInventoryError $errors "API inventory scope classification '$classification' is unsupported."
        }
        if ($ExpectedClassification -and $classification -cne $ExpectedClassification) {
            Add-CrowApiInventoryError $errors "API inventory classification must match '$ExpectedClassification'."
        }
        if ($ExpectedServiceName -and $serviceName -cne $ExpectedServiceName) {
            Add-CrowApiInventoryError $errors "API inventory serviceName must match '$ExpectedServiceName'."
        }
        if (-not [string]::IsNullOrWhiteSpace($ExpectedServicePath)) {
            if (-not [string]::IsNullOrWhiteSpace($servicePath)) {
                if ($servicePath.Replace('\', '/') -cne $ExpectedServicePath.Replace('\', '/')) {
                    Add-CrowApiInventoryError $errors "API inventory servicePath must match '$($ExpectedServicePath.Replace('\', '/'))'."
                }
            }
        }

        if ($classification -eq 'SingleApp') {
            if ($servicePath -cne '.') {
                Add-CrowApiInventoryError $errors "Single-app API inventory servicePath must be '.'."
            }
        }
        elseif ($classification -eq 'Monorepo' -and $servicePath -cne '.') {
            Resolve-CrowApiInventoryPath `
                -Root $root `
                -RelativePath $servicePath `
                -Context 'API inventory servicePath' `
                -Errors $errors `
                -RequireDirectory | Out-Null
        }
    }

    $completeness = Get-CrowApiInventoryString $inventory 'completeness' 'API inventory' $errors
    if ($completeness -notin @('Verified', 'Partial', 'Unknown')) {
        Add-CrowApiInventoryError $errors "API inventory completeness '$completeness' is unsupported."
    }
    if ($RequireComplete -and $completeness -cne 'Verified') {
        Add-CrowApiInventoryError $errors 'API modernization coverage requires completeness Verified.'
    }

    $hasEvidenceArray = Test-CrowApiInventoryObjectArray `
        -Object $inventory -Name 'evidence' -Context 'API inventory' `
        -Errors $errors
    $hasApiArray = Test-CrowApiInventoryObjectArray `
        -Object $inventory -Name 'apis' -Context 'API inventory' `
        -Errors $errors
    $hasUnknownArray = Test-CrowApiInventoryObjectArray `
        -Object $inventory -Name 'unknowns' -Context 'API inventory' `
        -Errors $errors -AllowEmpty
    if ($hasEvidenceArray -and $inventory.evidence.Count -eq 0) {
        Add-CrowApiInventoryError $errors 'API inventory evidence cannot be empty.'
    }
    if ($hasApiArray -and $inventory.apis.Count -eq 0) {
        Add-CrowApiInventoryError $errors 'API inventory must contain at least one API.'
    }

    $evidenceIds = [System.Collections.Generic.HashSet[string]]::new(
        [System.StringComparer]::Ordinal)
    if ($hasEvidenceArray) {
        foreach ($evidence in $inventory.evidence) {
            $evidenceId = Get-CrowApiInventoryString $evidence 'id' 'API inventory evidence' $errors
            if ($evidenceId -notmatch '^EV-[0-9]{3,}$') {
                Add-CrowApiInventoryError $errors "API inventory evidence has an invalid or duplicate id '$evidenceId'."
            }
            elseif (-not $evidenceIds.Add($evidenceId)) {
                Add-CrowApiInventoryError $errors "API inventory evidence has an invalid or duplicate id '$evidenceId'."
            }
            $evidencePath = Get-CrowApiInventoryString $evidence 'path' "API inventory evidence '$evidenceId'" $errors
            Resolve-CrowApiInventoryPath `
                -Root $root `
                -RelativePath $evidencePath `
                -Context "API inventory evidence '$evidenceId'" `
                -Errors $errors `
                -RequireFile | Out-Null
            Get-CrowApiInventoryString $evidence 'summary' "API inventory evidence '$evidenceId'" $errors | Out-Null
            $startLine = 0
            $endLine = 0
            if (-not [int]::TryParse([string]$evidence.startLine, [ref]$startLine) -or
                -not [int]::TryParse([string]$evidence.endLine, [ref]$endLine) -or
                $startLine -lt 1 -or $endLine -lt $startLine) {
                Add-CrowApiInventoryError $errors "API inventory evidence '$evidenceId' has an invalid line range."
            }
        }
    }

    $completenessEvidenceValid = Test-CrowApiInventoryStringArray `
        -Object $inventory -Name 'completenessEvidence' `
        -Context 'API inventory' -Errors $errors `
        -AllowEmpty:($completeness -ne 'Verified')
    if ($completenessEvidenceValid) {
        if ($completeness -eq 'Verified' -and $inventory.completenessEvidence.Count -eq 0) {
            Add-CrowApiInventoryError $errors 'Verified API inventory completeness requires completenessEvidence.'
        }
        foreach ($reference in $inventory.completenessEvidence) {
            if (-not $evidenceIds.Contains([string]$reference)) {
                Add-CrowApiInventoryError $errors "API inventory completeness references unknown evidence '$reference'."
            }
        }
    }

    $blockingUnknown = $false
    $unknownIds = [System.Collections.Generic.HashSet[string]]::new(
        [System.StringComparer]::Ordinal)
    if ($hasUnknownArray) {
        foreach ($unknown in $inventory.unknowns) {
            $unknownId = Get-CrowApiInventoryString $unknown 'id' 'API inventory unknown' $errors
            if ($unknownId -notmatch '^U-[0-9]{3,}$') {
                Add-CrowApiInventoryError $errors "API inventory unknown has an invalid or duplicate id '$unknownId'."
            }
            elseif (-not $unknownIds.Add($unknownId)) {
                Add-CrowApiInventoryError $errors "API inventory unknown has an invalid or duplicate id '$unknownId'."
            }
            Get-CrowApiInventoryString $unknown 'question' "API inventory unknown '$unknownId'" $errors | Out-Null
            if (-not ($unknown.PSObject.Properties.Name -contains 'blocksCompleteness') -or
                $unknown.blocksCompleteness -isnot [bool]) {
                Add-CrowApiInventoryError $errors "API inventory unknown '$unknownId' must declare boolean blocksCompleteness."
            }
            elseif ($unknown.blocksCompleteness) {
                $blockingUnknown = $true
            }
        }
    }
    if ($RequireComplete -and $blockingUnknown) {
        Add-CrowApiInventoryError $errors 'API modernization coverage is blocked by an unresolved question that may hide operations.'
    }
    elseif ($completeness -eq 'Verified' -and $blockingUnknown) {
        Add-CrowApiInventoryError $errors 'API inventory cannot be Verified while an unresolved question may hide operations.'
    }

    $apiIds = [System.Collections.Generic.HashSet[string]]::new(
        [System.StringComparer]::Ordinal)
    $operationIds = [System.Collections.Generic.HashSet[string]]::new(
        [System.StringComparer]::Ordinal)
    $responseCaseIds = [System.Collections.Generic.HashSet[string]]::new(
        [System.StringComparer]::Ordinal)
    if ($hasApiArray) {
        foreach ($api in $inventory.apis) {
            $apiId = Get-CrowApiInventoryString $api 'id' 'API inventory API' $errors
            if ($apiId -notmatch '^API-[0-9]{3,}$') {
                Add-CrowApiInventoryError $errors "API inventory contains an invalid or duplicate API id '$apiId'."
            }
            elseif (-not $apiIds.Add($apiId)) {
                Add-CrowApiInventoryError $errors "API inventory contains an invalid or duplicate API id '$apiId'."
            }
            Get-CrowApiInventoryString $api 'name' "API '$apiId'" $errors | Out-Null
            $protocol = Get-CrowApiInventoryString $api 'protocol' "API '$apiId'" $errors
            if ($protocol -notin $script:CrowApiProtocols) {
                Add-CrowApiInventoryError $errors "API '$apiId' has unsupported protocol '$protocol'."
            }
            Get-CrowApiInventoryString $api 'version' "API '$apiId'" $errors | Out-Null
            Get-CrowApiInventoryString $api 'owner' "API '$apiId'" $errors | Out-Null
            Get-CrowApiInventoryString $api 'authentication' "API '$apiId'" $errors | Out-Null
            Test-CrowApiInventoryStringArray `
                -Object $api -Name 'consumers' -Context "API '$apiId'" `
                -Errors $errors | Out-Null

            if (Test-CrowApiInventoryObjectArray `
                -Object $api -Name 'contracts' -Context "API '$apiId'" `
                -Errors $errors) {
                foreach ($contract in $api.contracts) {
                    $contractType = Get-CrowApiInventoryString $contract 'type' "API '$apiId' contract" $errors
                    if ($contractType -notin $script:CrowApiContractTypes) {
                        Add-CrowApiInventoryError $errors "API '$apiId' has unsupported contract type '$contractType'."
                    }
                    $contractEvidence = Get-CrowApiInventoryString $contract 'evidenceRef' "API '$apiId' contract" $errors
                    if ([string]::IsNullOrWhiteSpace($contractEvidence)) {
                        Add-CrowApiInventoryError $errors "API '$apiId' contract references unknown evidence '$contractEvidence'."
                    }
                    elseif (-not $evidenceIds.Contains($contractEvidence)) {
                        Add-CrowApiInventoryError $errors "API '$apiId' contract references unknown evidence '$contractEvidence'."
                    }
                }
            }

            if (-not (Test-CrowApiInventoryObjectArray `
                -Object $api -Name 'operations' -Context "API '$apiId'" `
                -Errors $errors)) {
                continue
            }
            foreach ($operation in $api.operations) {
                $operationId = Get-CrowApiInventoryString $operation 'id' "API '$apiId' operation" $errors
                if ($operationId -notmatch '^OP-[0-9]{3,}$') {
                    Add-CrowApiInventoryError $errors "API '$apiId' contains an invalid or duplicate operation id '$operationId'."
                }
                elseif (-not $operationIds.Add($operationId)) {
                    Add-CrowApiInventoryError $errors "API '$apiId' contains an invalid or duplicate operation id '$operationId'."
                }
                Get-CrowApiInventoryString $operation 'name' "Operation '$operationId'" $errors | Out-Null
                $confidence = Get-CrowApiInventoryString $operation 'confidence' "Operation '$operationId'" $errors
                if ($confidence -notin $script:CrowApiConfidence) {
                    Add-CrowApiInventoryError $errors "Operation '$operationId' has unsupported confidence '$confidence'."
                }
                $sideEffects = Get-CrowApiInventoryString $operation 'sideEffects' "Operation '$operationId'" $errors
                if ($sideEffects -notin $script:CrowApiSideEffects) {
                    Add-CrowApiInventoryError $errors "Operation '$operationId' has unsupported sideEffects '$sideEffects'."
                }
                if ($RequireComplete -and $confidence -ne 'Verified') {
                    Add-CrowApiInventoryError $errors "API modernization coverage requires operation '$operationId' confidence Verified."
                }
                if ($RequireComplete -and $sideEffects -eq 'Unknown') {
                    Add-CrowApiInventoryError $errors "API modernization coverage requires known side effects for operation '$operationId'."
                }
                Test-CrowApiInventoryEvidenceReference `
                    -Object $operation -Name 'evidenceRefs' `
                    -Context "Operation '$operationId'" `
                    -EvidenceIds $evidenceIds -Errors $errors `
                    -AllowEmpty:($confidence -ne 'Verified')

                if (Test-CrowApiInventoryObject $operation.http "Operation '$operationId' HTTP binding" $errors) {
                    $method = Get-CrowApiInventoryString $operation.http 'method' "Operation '$operationId' HTTP binding" $errors
                    if ($method -notin $script:CrowApiHttpMethods) {
                        Add-CrowApiInventoryError $errors "Operation '$operationId' has unsupported HTTP method '$method'."
                    }
                    $path = Get-CrowApiInventoryString $operation.http 'path' "Operation '$operationId' HTTP binding" $errors
                    if (-not [string]::IsNullOrWhiteSpace($path) -and $path -ne 'Unknown') {
                        if (-not $path.StartsWith('/') -or
                            $path -match '^[A-Za-z][A-Za-z0-9+.-]*://') {
                            Add-CrowApiInventoryError $errors "Operation '$operationId' HTTP path must begin with '/' or be Unknown."
                        }
                    }
                    if ($RequireComplete -and ($method -eq 'Unknown' -or $path -eq 'Unknown')) {
                        Add-CrowApiInventoryError $errors "API modernization coverage requires a known HTTP binding for operation '$operationId'."
                    }
                }

                Test-CrowApiInventoryStringArray `
                    -Object $operation -Name 'requestMediaTypes' `
                    -Context "Operation '$operationId'" -Errors $errors -AllowEmpty |
                    Out-Null

                foreach ($caseProperty in @('successResponses', 'errorResponses')) {
                    $hasCases = Test-CrowApiInventoryObjectArray `
                        -Object $operation -Name $caseProperty `
                        -Context "Operation '$operationId'" -Errors $errors `
                        -AllowEmpty:($caseProperty -eq 'errorResponses')
                    if (-not $hasCases) {
                        continue
                    }
                    foreach ($responseCase in $operation.$caseProperty) {
                        $caseId = Get-CrowApiInventoryString $responseCase 'id' "Operation '$operationId' response case" $errors
                        if ($caseId -notmatch '^RC-[0-9]{3,}$') {
                            Add-CrowApiInventoryError $errors "API inventory contains an invalid response case id '$caseId'."
                        }
                        elseif (-not $responseCaseIds.Add($caseId)) {
                            Add-CrowApiInventoryError $errors "API inventory contains a duplicate response case id '$caseId'."
                        }
                        $code = Get-CrowApiInventoryString $responseCase 'code' "Response case '$caseId'" $errors
                        if ($code -ne 'Unknown' -and $code -notmatch '^[1-5][0-9]{2}$') {
                            Add-CrowApiInventoryError $errors "Response case '$caseId' code must be an HTTP status code or Unknown."
                        }
                        if ($RequireComplete -and $code -eq 'Unknown') {
                            Add-CrowApiInventoryError $errors "API modernization coverage requires a known response code for case '$caseId'."
                        }
                        Get-CrowApiInventoryString $responseCase 'meaning' "Response case '$caseId'" $errors | Out-Null
                    }
                }

                if ($protocol -eq 'SOAP') {
                    if (Test-CrowApiInventoryObject $operation.soap "Operation '$operationId' SOAP contract" $errors) {
                        $soapVersion = Get-CrowApiInventoryString $operation.soap 'version' "Operation '$operationId' SOAP contract" $errors
                        if ($soapVersion -notin @('1.1', '1.2', 'Unknown')) {
                            Add-CrowApiInventoryError $errors "Operation '$operationId' has unsupported SOAP version '$soapVersion'."
                        }
                        Get-CrowApiInventoryString `
                            -Object $operation.soap `
                            -Name 'action' `
                            -Context "Operation '$operationId' SOAP contract" `
                            -Errors $errors `
                            -AllowEmpty | Out-Null
                        foreach ($property in @('requestElement', 'responseElement')) {
                            Get-CrowApiInventoryString `
                                -Object $operation.soap `
                                -Name $property `
                                -Context "Operation '$operationId' SOAP contract" `
                                -Errors $errors | Out-Null
                        }
                        Test-CrowApiInventoryStringArray `
                            -Object $operation.soap -Name 'faults' `
                            -Context "Operation '$operationId' SOAP contract" `
                            -Errors $errors -AllowEmpty | Out-Null
                    }
                }
                elseif ($operation.PSObject.Properties.Name -contains 'soap') {
                    Add-CrowApiInventoryError $errors "Non-SOAP operation '$operationId' must not contain a SOAP contract."
                }
            }
        }
    }

    return [pscustomobject]@{
        IsValid = ($errors.Count -eq 0)
        Errors = @($errors)
        Inventory = $inventory
    }
}

Export-ModuleMember -Function Test-CrowApiInventory
