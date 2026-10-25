[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$powerShellExecutable = (Get-Process -Id $PID).Path
$scriptDir = $PSScriptRoot
$selectorScript = Join-Path $scriptDir 'Select-CrowStrategy.ps1'
$validatorScript = Join-Path $scriptDir 'Test-CrowGraphManifest.ps1'
$runnerScript = Join-Path $scriptDir 'Invoke-CrowGraphRunner.ps1'

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) (
    "crow-coordinator-$([guid]::NewGuid().ToString('N'))")

function Assert-Condition {
    param(
        [bool]$Condition,
        [string]$Message
    )
    if (-not $Condition) {
        throw "Assertion failed: $Message"
    }
}

try {
    New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null

    # 1. Test strategy selector
    $direct = & $powerShellExecutable -NoProfile -File $selectorScript -TaskDescription 'Small doc edit' -EstimatedFiles 1 | ConvertFrom-Json
    Assert-Condition ($direct.Strategy -eq 'direct') "Direct strategy expected for 1 file"

    $graph = & $powerShellExecutable -NoProfile -File $selectorScript -TaskDescription 'Multi-phase audit' -HasPrerequisites | ConvertFrom-Json
    Assert-Condition ($graph.Strategy -eq 'graph') "Graph strategy expected when HasPrerequisites is true"

    $loop = & $powerShellExecutable -NoProfile -File $selectorScript -TaskDescription 'Iterative fix' -NeedsIterativeFeedback | ConvertFrom-Json
    Assert-Condition ($loop.Strategy -eq 'bounded-loop') "Bounded-loop strategy expected for iterative feedback"

    $batch = & $powerShellExecutable -NoProfile -File $selectorScript -TaskDescription 'Bulk updates' -IsBatch | ConvertFrom-Json
    Assert-Condition ($batch.Strategy -eq 'parallel-batch') "Parallel-batch strategy expected for batch tasks"

    # 2. Test manifest validation: Valid DAG
    $validManifestPath = Join-Path $tempRoot 'valid-dag.json'
    @{
        version = "1.0.0"
        graph_id = "test-dag"
        title = "Valid Test DAG"
        nodes = @(
            @{ id = "node1"; title = "Read context"; type = "read_only"; asset = "crow-project-context"; dependencies = @() },
            @{ id = "node2"; title = "Security review"; type = "read_only"; asset = "crow-security-review"; dependencies = @("node1") },
            @{ id = "node3"; title = "Apply fix"; type = "mutation"; asset = "crow-security-remediation"; dependencies = @("node2") }
        )
    } | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $validManifestPath -Encoding UTF8

    $validRes = & $powerShellExecutable -NoProfile -File $validatorScript -ManifestPath $validManifestPath
    Assert-Condition ($LASTEXITCODE -eq 0) "Valid manifest should pass validation with exit code 0"

    # 3. Test manifest validation: Cycle rejection
    $cycleManifestPath = Join-Path $tempRoot 'cycle-dag.json'
    @{
        version = "1.0.0"
        graph_id = "cycle-dag"
        title = "Cycle Test DAG"
        nodes = @(
            @{ id = "nodeA"; title = "A"; type = "read_only"; asset = "crow-project-context"; dependencies = @("nodeB") },
            @{ id = "nodeB"; title = "B"; type = "read_only"; asset = "crow-security-review"; dependencies = @("nodeA") }
        )
    } | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $cycleManifestPath -Encoding UTF8

    $cycleRes = & $powerShellExecutable -NoProfile -File $validatorScript -ManifestPath $cycleManifestPath 2>&1 | Out-String
    Assert-Condition ($LASTEXITCODE -ne 0) "Cycle manifest should fail validation with non-zero exit code"

    # 4. Test manifest validation: Duplicate node ID rejection
    $dupManifestPath = Join-Path $tempRoot 'dup-dag.json'
    @{
        version = "1.0.0"
        graph_id = "dup-dag"
        title = "Duplicate Node ID"
        nodes = @(
            @{ id = "node1"; title = "A"; type = "read_only"; asset = "crow-project-context"; dependencies = @() },
            @{ id = "node1"; title = "B"; type = "read_only"; asset = "crow-security-review"; dependencies = @() }
        )
    } | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $dupManifestPath -Encoding UTF8

    $dupRes = & $powerShellExecutable -NoProfile -File $validatorScript -ManifestPath $dupManifestPath 2>&1 | Out-String
    Assert-Condition ($LASTEXITCODE -ne 0) "Duplicate node ID should fail validation"

    # 5. Test manifest validation: Parallel mutation rejection without ordering
    $parallelMutPath = Join-Path $tempRoot 'parallel-mut-dag.json'
    @{
        version = "1.0.0"
        graph_id = "parallel-mut"
        title = "Parallel Mutations"
        nodes = @(
            @{ id = "mut1"; title = "M1"; type = "mutation"; asset = "crow-security-remediation"; dependencies = @() },
            @{ id = "mut2"; title = "M2"; type = "mutation"; asset = "crow-application-development"; dependencies = @() }
        )
    } | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $parallelMutPath -Encoding UTF8

    $parallelRes = & $powerShellExecutable -NoProfile -File $validatorScript -ManifestPath $parallelMutPath 2>&1 | Out-String
    Assert-Condition ($LASTEXITCODE -ne 0) "Parallel mutations without ordering should fail validation"

    # 6. Test graph runner dry-run
    $receiptPath = Join-Path $tempRoot 'receipt.json'
    $runnerRes = & $powerShellExecutable -NoProfile -File $runnerScript -ManifestPath $validManifestPath -DryRun -ReceiptPath $receiptPath
    Assert-Condition ($LASTEXITCODE -eq 0) "Runner dry-run should complete with exit code 0"
    Assert-Condition (Test-Path -LiteralPath $receiptPath) "Receipt file should be created"

    $receiptData = Get-Content -LiteralPath $receiptPath -Raw | ConvertFrom-Json
    Assert-Condition ($receiptData.GraphId -eq 'test-dag') "Receipt GraphId should match manifest"
    Assert-Condition ($receiptData.Status -eq 'succeeded') "Receipt Status should be succeeded"

    Write-Host 'Crow workflow coordinator tests passed.' -ForegroundColor Green
}
finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force
    }
}

exit 0
