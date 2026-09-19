[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$scriptPath = Join-Path $PSScriptRoot 'ConvertTo-CrowSecurityIssues.ps1'
$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) "crow-security-issues-$([guid]::NewGuid())"
$inputPath = Join-Path $tempRoot 'input.json'
$outputPath = Join-Path $tempRoot 'output'

try {
    [System.IO.Directory]::CreateDirectory($tempRoot) | Out-Null
    $input = [ordered]@{
        crowVersion = '0.8.1'
        repository = [ordered]@{
            provider = 'github'
            owner = 'example'
            name = 'sample-app'
        }
        services = @(
            [ordered]@{
                serviceName = 'api'
                servicePath = 'src/api'
                reportPath = 'docs/api/security-review.md'
                findings = @(
                    [ordered]@{
                        findingId = 'SEC-001'
                        title = 'Unsafe query construction'
                        severity = 'High'
                        classification = 'Confirmed'
                        file = 'src/api/query.ts'
                        startLine = 42
                        endLine = 44
                        owaspCategory = 'A05'
                        cweIds = @('CWE-89')
                        cvssScore = 8.1
                        description = 'Untrusted input reaches a query sink.'
                        affectedCode = 'query(input)'
                        exploitScenario = 'An attacker changes query structure.'
                        remediation = 'Use parameter binding.'
                        fixedCodeExample = 'query(sql, [input])'
                    }
                )
            }
        )
    }
    [System.IO.File]::WriteAllText($inputPath, ($input | ConvertTo-Json -Depth 20), [System.Text.UTF8Encoding]::new($false))

    & $scriptPath -InputPath $inputPath -OutputDirectory $outputPath | Out-Null

    $sarif = [System.IO.File]::ReadAllText((Join-Path $outputPath 'crow-security.sarif')) | ConvertFrom-Json
    $tickets = @([System.IO.File]::ReadAllText((Join-Path $outputPath 'crow-security-tickets.json')) | ConvertFrom-Json)
    if ($sarif.version -ne '2.1.0' -or $sarif.runs.Count -ne 1 -or $sarif.runs[0].results.Count -ne 1) {
        throw 'SARIF structure was not generated as expected.'
    }
    if ($tickets.Count -ne 1 -or @($tickets[0].labels) -notcontains 'crow-security') {
        throw 'Ticket payload was not generated with the required label.'
    }
    if ($tickets[0].body -notmatch '(?s)<!-- crow-sarif-result:start -->\r?\n```json\r?\n.+\r?\n```\r?\n<!-- crow-sarif-result:end -->') {
        throw 'Ticket body does not contain the canonical fenced SARIF result.'
    }

    $sarifResult = $sarif.runs[0].results[0] | ConvertTo-Json -Depth 20 -Compress
    $ticketResult = $tickets[0].sarifResult | ConvertTo-Json -Depth 20 -Compress
    if ($sarifResult -cne $ticketResult) {
        throw 'Ticket and GHAS SARIF results differ.'
    }

    $firstFingerprint = $tickets[0].crowFinding
    $input.services[0].findings[0].startLine = 142
    $input.services[0].findings[0].endLine = 144
    [System.IO.File]::WriteAllText($inputPath, ($input | ConvertTo-Json -Depth 20), [System.Text.UTF8Encoding]::new($false))
    & $scriptPath -InputPath $inputPath -OutputDirectory $outputPath | Out-Null
    $movedTickets = @([System.IO.File]::ReadAllText((Join-Path $outputPath 'crow-security-tickets.json')) | ConvertFrom-Json)
    if ($movedTickets[0].crowFinding -cne $firstFingerprint) {
        throw 'Fingerprint changed when only line numbers moved.'
    }

    Write-Output 'Crow security issue conversion tests passed.'
}
finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force
    }
}

exit 0
