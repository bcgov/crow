<#
.SYNOPSIS
    Executes approved deterministic commands in dependency order and records receipts.
.DESCRIPTION
    Crow asset names provide routing metadata; the runner does not invoke AI agents.
    Read commands run in bounded parallel batches. Mutation commands run exclusively
    in a supplied, clean, linked Git worktree. Commands are trusted operator code,
    not sandboxed; scope checks detect tracked and untracked file changes after execution.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$ManifestPath,
    [string]$WorktreePath,
    [switch]$DryRun,
    [string]$ReceiptPath = 'receipt.json',
    [string]$ApprovedManifestHash
)
$ErrorActionPreference = 'Stop'
$isValid = & (Join-Path $PSScriptRoot 'Test-CrowGraphManifest.ps1') -ManifestPath $ManifestPath
if (-not $isValid) { throw 'Cannot execute invalid graph manifest.' }
$manifest = Get-Content -LiteralPath $ManifestPath -Raw | ConvertFrom-Json
$nodes = @($manifest.nodes)
$executionPath = (Get-Location).Path
$states = @{}
foreach ($node in $nodes) {
    $states[$node.id] = [pscustomobject]@{
        Id = $node.id; Title = $node.title; Type = $node.type; Asset = $node.asset
        Status = 'pending'; StartTime = $null; EndTime = $null; Error = $null
    }
}
$receipt = [pscustomobject]@{
    GraphId = $manifest.graph_id; RunId = [guid]::NewGuid().ToString()
    StartTime = [datetime]::UtcNow.ToString('o'); EndTime = $null
    Status = 'running'; DryRun = [bool]$DryRun; WorktreePath = $null; Error = $null; NodeStates = @()
}
function Get-WorktreeSnapshot([string]$directory) {
    $paths = & git -C $directory -c core.quotePath=false ls-files --cached --others --exclude-standard
    if ($LASTEXITCODE -ne 0) { throw 'Unable to inspect worktree files.' }
    $snapshot = @{}
    foreach ($path in $paths) {
        $full = Join-Path $directory $path
        if (Test-Path -LiteralPath $full -PathType Leaf) { $snapshot[$path] = (Get-FileHash -LiteralPath $full -Algorithm SHA256).Hash }
        else { $snapshot[$path] = '<missing>' }
    }
    return $snapshot
}
$jobs = @()
try {
    if (-not $DryRun) {
        foreach ($node in $nodes) {
            if ($node.type -ne 'barrier' -and [string]::IsNullOrWhiteSpace($node.command)) {
                throw "Node '$($node.id)' requires a command; asset routing alone cannot execute work."
            }
        }
        if (@($nodes | Where-Object type -eq 'mutation').Count -gt 0) {
            if ($manifest.isolated_worktree -eq $false) { throw 'Mutation isolation cannot be disabled.' }
            if (-not $WorktreePath) { $WorktreePath = $manifest.worktree_path }
            if (-not $WorktreePath) { throw 'Supply an existing isolated Git worktree via WorktreePath or worktree_path.' }
            $executionPath = (Resolve-Path -LiteralPath $WorktreePath).Path
            if (-not (Test-Path -LiteralPath (Join-Path $executionPath '.git') -PathType Leaf)) {
                throw 'Mutation execution requires a linked Git worktree, not the primary checkout.'
            }
            $top = & git -C $executionPath rev-parse --show-toplevel
            if ($LASTEXITCODE -ne 0) { throw 'Invalid worktree root.' }
            $prefix = & git -C $executionPath rev-parse --show-prefix
            if ($LASTEXITCODE -ne 0 -or -not [string]::IsNullOrWhiteSpace($prefix)) { throw 'Invalid worktree root.' }
            $executionPath = $top
            $dirty = & git -C $executionPath status --porcelain --untracked-files=all
            if ($LASTEXITCODE -ne 0 -or $dirty) { throw 'Mutation worktree must start clean.' }
            $initialHead = & git -C $executionPath rev-parse HEAD
            $receipt.WorktreePath = $executionPath
        }
        $hash = (Get-FileHash -LiteralPath $ManifestPath -Algorithm SHA256).Hash
        $mode = if ($manifest.approval_mode) { $manifest.approval_mode } else { 'prompt' }
        if ($ApprovedManifestHash -and $ApprovedManifestHash -ne $hash) { throw 'Approved manifest hash does not match.' }
        if ($mode -eq 'none' -and $receipt.WorktreePath) { throw 'Mutation graphs require operator approval mode prompt or manifest_hash.' }
        if (-not $ApprovedManifestHash) {
            if ($mode -eq 'manifest_hash') { throw 'Provide ApprovedManifestHash from operator review.' }
            if ($mode -eq 'prompt' -and (Read-Host "Execute reviewed manifest SHA256 $hash ? Type yes") -cne 'yes') {
                throw 'Execution was not approved.'
            }
        }
    }
    $limit = if ($manifest.max_concurrency) { $manifest.max_concurrency } else { 4 }
    while (@($nodes | Where-Object { $states[$_.id].Status -eq 'pending' }).Count -gt 0) {
        $ready = @($nodes | Where-Object {
            $states[$_.id].Status -eq 'pending' -and
            @($_.dependencies | Where-Object { $null -ne $_ -and $states[$_].Status -ne 'succeeded' }).Count -eq 0
        })
        if ($ready.Count -eq 0) { throw 'Pending nodes have blocked prerequisites.' }
        # A writer runs alone; other ready nodes are deferred to the next batch.
        $writer = @($ready | Where-Object type -eq 'mutation')
        $batch = if ($writer.Count) { @($writer[0]) } else { @($ready | Select-Object -First $limit) }
        $jobs = @()
        if (-not $DryRun -and $writer.Count) { $before = Get-WorktreeSnapshot $executionPath }
        foreach ($node in $batch) {
            $state = $states[$node.id]
            $state.StartTime = [datetime]::UtcNow.ToString('o')
            $state.Status = 'running'
            if ($DryRun -or ($node.type -eq 'barrier' -and -not $node.verifier)) {
                $state.Status = 'succeeded'; $state.EndTime = [datetime]::UtcNow.ToString('o')
                continue
            }
            $job = Start-ThreadJob -ArgumentList $node, $executionPath -ScriptBlock {
                param($node, $directory)
                $ErrorActionPreference = 'Stop'
                function Invoke-CheckedCommand([string]$command) {
                    # EncodedCommand preserves quotes and whitespace across process boundaries.
                    $wrapped = "`$ErrorActionPreference = 'Stop'; `$PSNativeCommandUseErrorActionPreference = `$true; & { $command }; if (-not `$?) { exit 1 }; if (`$null -ne `$LASTEXITCODE) { exit `$LASTEXITCODE }"
                    $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($wrapped))
                    & (Join-Path $PSHOME 'pwsh') -NoProfile -NonInteractive -EncodedCommand $encoded | Out-Host
                    if ($LASTEXITCODE -ne 0) { throw "Command exited with code $LASTEXITCODE" }
                }
                try {
                    Set-Location -LiteralPath $directory
                    if ($node.type -ne 'barrier') { Invoke-CheckedCommand $node.command }
                    if ($node.verifier) {
                        if ($node.verifier.type -eq 'command') { Invoke-CheckedCommand $node.verifier.target }
                        elseif (-not (Test-Path -LiteralPath $node.verifier.target -PathType Leaf)) { throw 'Verifier artifact is missing.' }
                    }
                    [pscustomobject]@{ NodeId = $node.id; Error = $null }
                }
                catch { [pscustomobject]@{ NodeId = $node.id; Error = $_.Exception.Message } }
            }
            $jobs += @{ Node = $node; Job = $job }
        }
        foreach ($entry in $jobs) {
            $job = $entry.Job
            $job | Wait-Job | Out-Null
            $result = @($job | Receive-Job -ErrorAction Continue | Where-Object { $_.PSObject.Properties['NodeId'] })
            $state = $states[$entry.Node.id]
            $state.EndTime = [datetime]::UtcNow.ToString('o')
            if ($job.State -ne 'Completed' -or $result.Count -ne 1 -or $result[0].Error) {
                $state.Status = 'failed'
                $state.Error = if ($result.Count) { $result[0].Error } else { 'Command job did not complete.' }
            }
            else { $state.Status = 'succeeded' }
            if ($entry.Node.type -eq 'mutation') {
                $after = Get-WorktreeSnapshot $executionPath
                $changed = @(@($before.Keys) + @($after.Keys) | Sort-Object -Unique | Where-Object { $before[$_] -cne $after[$_] })
                $currentHead = & git -C $executionPath rev-parse HEAD
                if ($LASTEXITCODE -ne 0 -or $currentHead -ne $initialHead) {
                    $state.Status = 'failed'; $state.Error = 'Mutation changed Git HEAD; workers must not commit.'
                }
                foreach ($path in $changed) {
                    $allowed = @($entry.Node.mutation_targets | Where-Object { $path -ceq $_.TrimEnd('/') -or $path.StartsWith($_.TrimEnd('/') + '/', [StringComparison]::Ordinal) }).Count -gt 0
                    $forbidden = @($entry.Node.forbidden_paths | Where-Object { $null -ne $_ -and ($path -ceq $_.TrimEnd('/') -or $path.StartsWith($_.TrimEnd('/') + '/', [StringComparison]::Ordinal)) }).Count -gt 0
                    if (-not $allowed -or $forbidden) { $state.Status = 'failed'; $state.Error = "Mutation scope violation: $path" }
                }
            }
        }
        foreach ($entry in $jobs) { Remove-Job $entry.Job -Force }
        $jobs = @()
        if (@($states.Values | Where-Object Status -eq 'failed').Count) { throw 'Node execution or verification failed.' }
    }
    $receipt.Status = 'succeeded'
}
catch { $receipt.Status = 'failed'; $receipt.Error = $_.Exception.Message; Write-Warning $receipt.Error }
finally {
    foreach ($entry in $jobs) { $entry.Job | Stop-Job; Remove-Job $entry.Job -Force }
    foreach ($state in $states.Values) { if ($state.Status -in @('pending', 'running')) { $state.Status = 'blocked' } }
    $receipt.EndTime = [datetime]::UtcNow.ToString('o')
    $receipt.NodeStates = @($nodes | ForEach-Object { $states[$_.id] })
    $parent = Split-Path $ReceiptPath -Parent
    if ($parent) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    $receipt | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $ReceiptPath -Encoding UTF8
}
$receipt
if ($receipt.Status -eq 'failed') { exit 1 }
