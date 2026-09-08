<#
.SYNOPSIS
  Validates a business-rules-data.json file against the authoritative Crow
  business-rule contract, optionally comparing it with the previously committed
  data file so stable identifiers cannot disappear, reactivate, or be reused.

.DESCRIPTION
  Use before committing regenerated data, and in target-repository checks.
  Exits 0 when the data is valid and 1 with one message per failure otherwise.
  business-rules-data.schema.json documents the same contract for editors;
  this script and the module it imports decide.

.PARAMETER DataFile
  Path to the regenerated business-rules-data.json.

.PARAMETER PreviousDataFile
  Path to the previously committed business-rules-data.json, used as the
  identifier ledger. Extract it with Export-PreviousBusinessRuleData.ps1, which
  copies git's output byte for byte:
  './Export-PreviousBusinessRuleData.ps1 -Destination previous-business-rules-data.json'.
  Do not use shell redirection: '>' rewrites the file as UTF-16 in Windows
  PowerShell 5.1 and corrupts non-ASCII rule text. Every regeneration of an
  existing report should supply it.

.PARAMETER AllowRetiredRuleReactivation
  Explicit override that permits a retired identifier to become active again.
  Requires -PreviousDataFile, reports the accepted risk, and is only correct
  when the identical rule was restored in the implementation. Without it,
  reactivation fails the run.

.EXAMPLE
  ./Test-BusinessRuleData.ps1 -DataFile docs/business-rules-data.json

.EXAMPLE
  ./Export-PreviousBusinessRuleData.ps1 -Destination previous-business-rules-data.json
  ./Test-BusinessRuleData.ps1 -DataFile docs/business-rules-data.json -PreviousDataFile previous-business-rules-data.json
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$DataFile,
    [string]$PreviousDataFile,
    [switch]$AllowRetiredRuleReactivation
)

$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot 'CrowBusinessRules.psm1') -Force

function Read-DataFile {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Label
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "$Label not found: $Path"
    }
    try {
        return [System.IO.File]::ReadAllText((Resolve-Path -LiteralPath $Path).Path) | ConvertFrom-Json
    }
    catch {
        throw "$Label is not valid JSON: $($_.Exception.Message)"
    }
}

try {
    if ($AllowRetiredRuleReactivation -and [string]::IsNullOrWhiteSpace($PreviousDataFile)) {
        throw ('-AllowRetiredRuleReactivation only applies to a ledger comparison. ' +
            'Supply -PreviousDataFile with the previously committed data file.')
    }

    $data = Read-DataFile -Path $DataFile -Label 'business-rules-data.json'
    $validationErrors = New-Object 'System.Collections.Generic.List[string]'
    foreach ($validationError in @(Test-CrowBusinessRuleData -Data $data)) {
        $validationErrors.Add($validationError)
    }

    $risks = New-Object 'System.Collections.Generic.List[string]'
    if (-not [string]::IsNullOrWhiteSpace($PreviousDataFile)) {
        $previousData = Read-DataFile -Path $PreviousDataFile -Label 'The previous business-rules-data.json'
        Test-CrowBusinessRuleLedger -PreviousData $previousData -CurrentData $data `
            -AllowRetiredRuleReactivation:$AllowRetiredRuleReactivation `
            -Errors $validationErrors -Risks $risks
    }
}
catch {
    Write-Error $_.Exception.Message -ErrorAction Continue
    exit 1
}

foreach ($risk in $risks) {
    Write-Warning $risk
}
foreach ($validationError in $validationErrors) {
    Write-Error $validationError -ErrorAction Continue
}

if ([string]::IsNullOrWhiteSpace($PreviousDataFile)) {
    Write-Host ('Business rule data validation: ' +
        "$($validationErrors.Count) error(s). No ledger comparison was requested.")
}
else {
    Write-Host ('Business rule data validation: ' +
        "$($validationErrors.Count) error(s), $($risks.Count) accepted ledger risk(s).")
}
if ($validationErrors.Count -gt 0) {
    exit 1
}
exit 0
