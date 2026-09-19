[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$InputPath,

    [Parameter(Mandatory = $true)]
    [string]$OutputDirectory
)

$ErrorActionPreference = 'Stop'

function Get-RequiredValue {
    param(
        [object]$Object,
        [string]$Name,
        [string]$Context
    )

    if (-not ($Object.PSObject.Properties.Name -contains $Name)) {
        throw "$Context is missing required property '$Name'."
    }
    $value = $Object.$Name
    if ($null -eq $value -or ($value -is [string] -and [string]::IsNullOrWhiteSpace($value))) {
        throw "$Context property '$Name' cannot be empty."
    }
    return $value
}

function Get-OptionalValue {
    param(
        [object]$Object,
        [string]$Name,
        [object]$Default
    )

    if ($Object.PSObject.Properties.Name -contains $Name) {
        return $Object.$Name
    }
    return $Default
}

function Get-Sha256 {
    param([string]$Value)

    $algorithm = [System.Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($Value)
        return ([System.BitConverter]::ToString($algorithm.ComputeHash($bytes))).Replace('-', '').ToLowerInvariant()
    }
    finally {
        $algorithm.Dispose()
    }
}

function ConvertTo-Level {
    param([string]$Severity)

    switch ($Severity.ToLowerInvariant()) {
        'critical' { return 'error' }
        'high' { return 'error' }
        'medium' { return 'warning' }
        'low' { return 'note' }
        'informational' { return 'note' }
        default { throw "Unsupported severity '$Severity'." }
    }
}

function ConvertTo-RelativeUri {
    param(
        [string]$Path,
        [string]$Context
    )

    $normalizedPath = $Path.Replace('\', '/')
    if ($normalizedPath -match '^/' -or
        $normalizedPath -match '^[A-Za-z]:(?:/|$)' -or
        $normalizedPath -match '^[A-Za-z][A-Za-z0-9+.-]*:' -or
        $normalizedPath -match '(^|/)\.\.(/|$)') {
        throw "$Context must use a repository-relative file path."
    }
    return $normalizedPath
}

$resolvedInput = (Resolve-Path -LiteralPath $InputPath).Path
$inputData = [System.IO.File]::ReadAllText($resolvedInput) | ConvertFrom-Json
$repository = Get-RequiredValue -Object $inputData -Name 'repository' -Context 'Input'
$repositoryProvider = [string](Get-RequiredValue -Object $repository -Name 'provider' -Context 'Repository')
$repositoryName = [string](Get-RequiredValue -Object $repository -Name 'name' -Context 'Repository')
$repositoryOwner = [string](Get-OptionalValue -Object $repository -Name 'owner' -Default '')
$services = @(Get-RequiredValue -Object $inputData -Name 'services' -Context 'Input')

if ($services.Count -eq 0) {
    throw 'Input must contain at least one service.'
}

$runs = [System.Collections.Generic.List[object]]::new()
$tickets = [System.Collections.Generic.List[object]]::new()
$fingerprints = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)

foreach ($service in $services) {
    $serviceName = [string](Get-RequiredValue -Object $service -Name 'serviceName' -Context 'Service')
    $servicePath = [string](Get-RequiredValue -Object $service -Name 'servicePath' -Context "Service '$serviceName'")
    $reportPath = ConvertTo-RelativeUri -Path ([string](Get-RequiredValue -Object $service -Name 'reportPath' -Context "Service '$serviceName'")) -Context "Service '$serviceName' reportPath"
    $findings = @(Get-RequiredValue -Object $service -Name 'findings' -Context "Service '$serviceName'")
    $results = [System.Collections.Generic.List[object]]::new()
    $rules = [System.Collections.Generic.List[object]]::new()
    $ruleIds = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)

    foreach ($finding in $findings) {
        $findingId = [string](Get-RequiredValue -Object $finding -Name 'findingId' -Context "Finding in '$serviceName'")
        $title = [string](Get-RequiredValue -Object $finding -Name 'title' -Context "Finding '$findingId'")
        $severity = [string](Get-RequiredValue -Object $finding -Name 'severity' -Context "Finding '$findingId'")
        $classification = [string](Get-RequiredValue -Object $finding -Name 'classification' -Context "Finding '$findingId'")
        $file = ConvertTo-RelativeUri -Path ([string](Get-RequiredValue -Object $finding -Name 'file' -Context "Finding '$findingId'")) -Context "Finding '$findingId' file"
        $startLine = [int](Get-RequiredValue -Object $finding -Name 'startLine' -Context "Finding '$findingId'")
        $endLine = [int](Get-OptionalValue -Object $finding -Name 'endLine' -Default $startLine)
        $description = [string](Get-RequiredValue -Object $finding -Name 'description' -Context "Finding '$findingId'")
        $remediation = [string](Get-RequiredValue -Object $finding -Name 'remediation' -Context "Finding '$findingId'")

        if ($startLine -lt 1 -or $endLine -lt $startLine) {
            throw "Finding '$findingId' has an invalid line range."
        }

        $identity = "$repositoryProvider/$repositoryOwner/$repositoryName|$servicePath|$findingId|$file"
        $fingerprint = Get-Sha256 -Value $identity
        if (-not $fingerprints.Add($fingerprint)) {
            throw "Duplicate Crow finding fingerprint for '$findingId' in '$serviceName'."
        }

        $message = "$title - $description"
        $properties = [ordered]@{
            findingId = $findingId
            severity = $severity
            classification = $classification
            serviceName = $serviceName
            reportPath = $reportPath
            owaspCategory = [string](Get-OptionalValue -Object $finding -Name 'owaspCategory' -Default '')
            cweIds = @(Get-OptionalValue -Object $finding -Name 'cweIds' -Default @())
            cvssScore = Get-OptionalValue -Object $finding -Name 'cvssScore' -Default $null
            description = $description
            affectedCode = [string](Get-OptionalValue -Object $finding -Name 'affectedCode' -Default '')
            exploitScenario = [string](Get-OptionalValue -Object $finding -Name 'exploitScenario' -Default '')
            remediation = $remediation
            fixedCodeExample = [string](Get-OptionalValue -Object $finding -Name 'fixedCodeExample' -Default '')
        }
        $result = [ordered]@{
            ruleId = $findingId
            level = ConvertTo-Level -Severity $severity
            message = [ordered]@{ text = $message }
            locations = @(
                [ordered]@{
                    physicalLocation = [ordered]@{
                        artifactLocation = [ordered]@{ uri = $file }
                        region = [ordered]@{
                            startLine = $startLine
                            endLine = $endLine
                        }
                    }
                }
            )
            partialFingerprints = [ordered]@{ crowFinding = $fingerprint }
            properties = $properties
        }
        $results.Add($result)

        if ($ruleIds.Add($findingId)) {
            $rules.Add([ordered]@{
                id = $findingId
                name = $title
                shortDescription = [ordered]@{ text = $title }
                properties = [ordered]@{
                    severity = $severity
                    tags = @('security')
                }
            })
        }

        $resultJson = $result | ConvertTo-Json -Depth 20
        $body = @(
            '## Crow security finding'
            ''
            '<!-- crow-sarif-result:start -->'
            '```json'
            $resultJson
            '```'
            '<!-- crow-sarif-result:end -->'
        ) -join [System.Environment]::NewLine
        $ticket = [ordered]@{
            title = "[$findingId] [$severity] $title"
            labels = @('crow-security')
            crowFinding = $fingerprint
            body = $body
            sarifResult = $result
        }

        $roundTrip = (($ticket.sarifResult | ConvertTo-Json -Depth 20 -Compress) | ConvertFrom-Json) | ConvertTo-Json -Depth 20 -Compress
        $canonical = (($result | ConvertTo-Json -Depth 20 -Compress) | ConvertFrom-Json) | ConvertTo-Json -Depth 20 -Compress
        if ($roundTrip -cne $canonical) {
            throw "Ticket SARIF result differs from GHAS result for '$findingId'."
        }
        $tickets.Add($ticket)
    }

    $automationId = "$repositoryProvider/$repositoryOwner/$repositoryName/$servicePath"
    $runs.Add([ordered]@{
        tool = [ordered]@{
            driver = [ordered]@{
                name = 'Crow Security Review'
                semanticVersion = [string](Get-OptionalValue -Object $inputData -Name 'crowVersion' -Default '')
                rules = @($rules)
            }
        }
        automationDetails = [ordered]@{ id = $automationId }
        results = @($results)
    })
}

$sarif = [ordered]@{
    '$schema' = 'https://json.schemastore.org/sarif-2.1.0.json'
    version = '2.1.0'
    runs = @($runs)
}

[System.IO.Directory]::CreateDirectory($OutputDirectory) | Out-Null
$sarifPath = Join-Path $OutputDirectory 'crow-security.sarif'
$ticketsPath = Join-Path $OutputDirectory 'crow-security-tickets.json'
$ticketPayloads = $tickets.ToArray()
[System.IO.File]::WriteAllText($sarifPath, ($sarif | ConvertTo-Json -Depth 20), [System.Text.UTF8Encoding]::new($false))
[System.IO.File]::WriteAllText($ticketsPath, (ConvertTo-Json -InputObject $ticketPayloads -Depth 20), [System.Text.UTF8Encoding]::new($false))

Write-Output "Created SARIF: $sarifPath"
Write-Output "Created ticket payloads: $ticketsPath"
