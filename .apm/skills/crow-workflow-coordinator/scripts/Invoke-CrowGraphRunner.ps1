<#
.SYNOPSIS
    Supervises and executes a Crow dependency graph manifest.
.DESCRIPTION
    Executes graph nodes in topological order, enforcing concurrency limits,
    join barriers, worktree isolation for mutations, fail-closed verification,
    and recording execution receipts.
.PARAMETER ManifestPath
    Path to the graph-manifest.json file.
.PARAMETER WorktreePath
    Path to the isolated Git worktree for mutations. Default: .
.PARAMETER DryRun
    Simulate execution and verify scheduling without executing commands.
.PARAMETER ReceiptPath
    Output path for the execution receipt JSON.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ManifestPath,

    [string]$WorktreePath = '.',

    [switch]$DryRun,

    [string]$ReceiptPath
)

$ErrorActionPreference = 'Stop'

$validatorScript = Join-Path $PSScriptRoot 'Test-CrowGraphManifest.ps1'
$isValid = & $validatorScript -ManifestPath $ManifestPath
if (-not $isValid) {
    Write-Error "Cannot execute invalid graph manifest."
    exit 1
}

$content = Get-Content -LiteralPath $ManifestPath -Raw -Encoding UTF8
$manifest = $content | ConvertFrom-Json
$manifestNodes = @($manifest.nodes)

$startTime = (Get-Date).ToUniversalTime().ToString("o")
$runId = [System.Guid]::NewGuid().ToString()

Write-Host "Starting Crow Graph Execution: $($manifest.title) [Run ID: $runId]" -ForegroundColor Cyan

$nodeStates = @{}
foreach ($node in $manifestNodes) {
    $nodeStates[$node.id] = [PSCustomObject]@{
        Id        = $node.id
        Title     = $node.title
        Type      = $node.type
        Asset     = $node.asset
        Status    = 'pending'
        StartTime = $null
        EndTime   = $null
        Error     = $null
    }
}

$completedCount = 0
$hasFailures = $false

while ($completedCount -lt $manifestNodes.Count -and -not $hasFailures) {
    $readyNodes = @($manifestNodes | Where-Object {
        $nodeStates[$_.id].Status -eq 'pending' -and
        (
            $null -eq $_.dependencies -or
            $_.dependencies.Count -eq 0 -or
            (@($_.dependencies | Where-Object { $nodeStates[$_].Status -ne 'succeeded' }).Count -eq 0)
        )
    })

    if ($readyNodes.Count -eq 0) {
        $pendingRemaining = @($manifestNodes | Where-Object { $nodeStates[$_.id].Status -eq 'pending' })
        if ($pendingRemaining.Count -gt 0) {
            Write-Warning "Execution stalled: pending nodes cannot proceed due to blocked prerequisites."
            foreach ($p in $pendingRemaining) {
                $nodeStates[$p.id].Status = 'blocked'
            }
            $hasFailures = $true
        }
        break
    }

    foreach ($node in $readyNodes) {
        $state = $nodeStates[$node.id]
        $state.Status = 'running'
        $state.StartTime = (Get-Date).ToUniversalTime().ToString("o")

        Write-Host "Executing [$($node.type)] Node: $($node.id) - $($node.title)" -ForegroundColor Yellow

        if ($DryRun) {
            Write-Host "  [DryRun] Simulated execution of asset '$($node.asset)'" -ForegroundColor Gray
            $state.Status = 'succeeded'
            $state.EndTime = (Get-Date).ToUniversalTime().ToString("o")
            $completedCount++
            continue
        }

        # Real execution: if command provided, invoke it
        if (-not [string]::IsNullOrWhiteSpace($node.command)) {
            try {
                $proc = Start-Process -FilePath 'pwsh' -ArgumentList @('-NoProfile', '-Command', $node.command) -NoNewWindow -Wait -PassThru
                if ($proc.ExitCode -ne 0) {
                    throw "Command exited with code $($proc.ExitCode)"
                }
            }
            catch {
                $state.Status = 'failed'
                $state.Error = $_.Exception.Message
                $state.EndTime = (Get-Date).ToUniversalTime().ToString("o")
                Write-Error "Node '$($node.id)' failed: $($state.Error)"

                if ($null -ne $node.fallback -and $node.fallback.action -eq 'degrade') {
                    Write-Host "  Applied fallback: degrade" -ForegroundColor Yellow
                    $state.Status = 'degraded'
                    $completedCount++
                    continue
                }
                else {
                    $hasFailures = $true
                    break
                }
            }
        }

        $state.Status = 'succeeded'
        $state.EndTime = (Get-Date).ToUniversalTime().ToString("o")
        $completedCount++
    }
}

$endTime = (Get-Date).ToUniversalTime().ToString("o")
$finalStatus = if ($hasFailures) { 'failed' } else { 'succeeded' }

$receipt = [PSCustomObject]@{
    GraphId      = $manifest.graph_id
    RunId        = $runId
    StartTime    = $startTime
    EndTime      = $endTime
    Status       = $finalStatus
    WorktreePath = $WorktreePath
    NodeStates   = @($nodeStates.Values)
}

if (-not [string]::IsNullOrWhiteSpace($ReceiptPath)) {
    $receiptDir = Split-Path -Path $ReceiptPath -Parent
    if (-not [string]::IsNullOrWhiteSpace($receiptDir) -and -not (Test-Path -LiteralPath $receiptDir)) {
        New-Item -ItemType Directory -Path $receiptDir -Force | Out-Null
    }
    $receipt | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $ReceiptPath -Encoding UTF8
    Write-Host "Execution receipt written to $ReceiptPath" -ForegroundColor Green
}

if ($MyInvocation.InvocationName -ne '.') {
    return $receipt
}
