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
            @{ id = "node3"; title = "Apply fix"; type = "mutation"; asset = "crow-security-remediation"; dependencies = @("node2"); mutation_targets = @("src") }
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
            @{ id = "mut1"; title = "M1"; type = "mutation"; asset = "crow-security-remediation"; dependencies = @(); mutation_targets = @("src") },
            @{ id = "mut2"; title = "M2"; type = "mutation"; asset = "crow-application-development"; dependencies = @(); mutation_targets = @("src") }
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

    # Schema and topology regression cases must fail for the intended reason.
    function Test-RejectedManifest($data, [string]$expected) {
        $path = Join-Path $tempRoot 'invalid.json'
        $data | ConvertTo-Json -Depth 20 | Set-Content $path
        $output = & $powerShellExecutable -NoProfile -File $validatorScript -ManifestPath $path 2>&1 | Out-String
        Assert-Condition ($LASTEXITCODE -ne 0 -and $output.Contains($expected)) "Expected rejection: $expected; got $output"
    }
    foreach ($change in @('version', 'max_concurrency', 'dependencies', 'title', 'verifier', 'fallback')) {
        $data = Get-Content $validManifestPath -Raw | ConvertFrom-Json
        switch ($change) {
            version { $data.version = '2.0.0' }
            max_concurrency { $data | Add-Member max_concurrency 0 }
            dependencies { $data.nodes[0].dependencies = 'not-an-array' }
            title { $data.nodes[0].PSObject.Properties.Remove('title') }
            verifier { $data.nodes[0] | Add-Member verifier @{type='artifact_valid';target='x'} }
            fallback { $data.nodes[0] | Add-Member fallback @{action='degrade'} }
        }
        Test-RejectedManifest $data 'does not conform'
    }
    $data = Get-Content $validManifestPath -Raw | ConvertFrom-Json
    $data.nodes[0].asset = 'crow-missing-asset'
    Test-RejectedManifest $data 'unknown Crow asset'
    $data = Get-Content $validManifestPath -Raw | ConvertFrom-Json
    $data.nodes[0].dependencies = @('missing')
    Test-RejectedManifest $data 'undefined dependency'
    $data = Get-Content $validManifestPath -Raw | ConvertFrom-Json
    $data.nodes[2].mutation_targets = @('../outside')
    Test-RejectedManifest $data 'unsafe scope path'
    $ordered = Get-Content $parallelMutPath -Raw | ConvertFrom-Json
    $ordered.nodes[1].dependencies = @('mut1')
    $ordered | ConvertTo-Json -Depth 10 | Set-Content $parallelMutPath
    $null = & $powerShellExecutable -NoProfile -File $validatorScript -ManifestPath $parallelMutPath
    Assert-Condition ($LASTEXITCODE -eq 0) 'Ordered mutations should pass'
    $selected = & $powerShellExecutable -NoProfile -File $selectorScript -TaskDescription 'dependent batch' -IsBatch -HasPrerequisites | ConvertFrom-Json
    Assert-Condition ($selected.Strategy -eq 'graph') 'Dependencies must override batch dispatch'
    $selected = & $powerShellExecutable -NoProfile -File $selectorScript -TaskDescription 'three files' -EstimatedFiles 3 | ConvertFrom-Json
    Assert-Condition ($selected.Strategy -eq 'graph') 'Direct execution is limited to two files'

    function Invoke-TestGraph($data, [int]$expectedExit, $extraArgs = @()) {
        $path = Join-Path $tempRoot 'runtime.json'
        $receipt = Join-Path $tempRoot 'runtime-receipt.json'
        if (Test-Path $receipt) { Remove-Item $receipt }
        $data | ConvertTo-Json -Depth 20 | Set-Content $path
        $hash = (Get-FileHash $path).Hash
        $null = & $powerShellExecutable -NoProfile -File $runnerScript -ManifestPath $path -ReceiptPath $receipt -ApprovedManifestHash $hash @extraArgs
        Assert-Condition ($LASTEXITCODE -eq $expectedExit) "Expected runtime exit $expectedExit; receipt: $(Get-Content $receipt -Raw)"
        Assert-Condition (Test-Path $receipt) 'Runtime receipt must exist on success and failure'
        return Get-Content $receipt -Raw | ConvertFrom-Json
    }
    $runtime = @{
        version='1.0.0';graph_id='runtime';title='Runtime';max_concurrency=2
        nodes=@(
            @{id='first';title='First';type='read_only';asset='crow-testing';command='exit 7'},
            @{id='next';title='Next';type='barrier';asset='crow-testing';dependencies=@('first')}
        )
    }
    $res = Invoke-TestGraph $runtime 1
    Assert-Condition ($res.NodeStates[0].Status -eq 'failed' -and $res.NodeStates[1].Status -eq 'blocked') 'Failure must block descendants'
    $runtime.nodes[0].command = "Write-Output 'quoted value with spaces'"
    $runtime.nodes[0].verifier = @{type='command';target='exit 9'}
    $res = Invoke-TestGraph $runtime 1
    Assert-Condition ($res.NodeStates[0].Status -eq 'failed') 'Verifier failure must fail node'
    $runtime.nodes[0].Remove('verifier')
    $res = Invoke-TestGraph $runtime 0
    Assert-Condition ($res.Status -eq 'succeeded') 'Quoted commands and barrier should succeed'
    $runtime.nodes[0].Remove('command')
    $res = Invoke-TestGraph $runtime 1
    Assert-Condition ($res.Error.Contains('requires a command')) 'Asset-only execution must fail closed'

    # Approval failures are recorded without running any node.
    $approvalPath = Join-Path $tempRoot 'approval.json'
    $approvalReceipt = Join-Path $tempRoot 'approval-receipt.json'
    $runtime.nodes[0].command = 'exit 0'
    $runtime.approval_mode = 'manifest_hash'
    $runtime | ConvertTo-Json -Depth 10 | Set-Content $approvalPath
    $null = & $powerShellExecutable -NoProfile -NonInteractive -File $runnerScript -ManifestPath $approvalPath -ReceiptPath $approvalReceipt
    Assert-Condition ($LASTEXITCODE -eq 1) 'Missing approval hash must fail'
    $approval = Get-Content $approvalReceipt -Raw | ConvertFrom-Json
    Assert-Condition ($approval.Error.Contains('Provide ApprovedManifestHash')) 'Missing hash rejection should be explicit'
    $null = & $powerShellExecutable -NoProfile -NonInteractive -File $runnerScript -ManifestPath $approvalPath -ReceiptPath $approvalReceipt -ApprovedManifestHash bad
    Assert-Condition ($LASTEXITCODE -eq 1) 'Wrong approval hash must fail'
    $runtime.Remove('approval_mode')

    # Independent commands must overlap; each waits for the other's marker.
    $markerA = (Join-Path $tempRoot 'a.marker').Replace("'", "''")
    $markerB = (Join-Path $tempRoot 'b.marker').Replace("'", "''")
    $runtime.nodes = @(
        @{id='a';title='A';type='read_only';asset='crow-testing';command="Set-Content '$markerA' ready; for (`$i=0; `$i -lt 100 -and -not (Test-Path '$markerB'); `$i++) { Start-Sleep -Milliseconds 50 }; if (-not (Test-Path '$markerB')) { exit 4 }"},
        @{id='b';title='B';type='read_only';asset='crow-testing';command="Set-Content '$markerB' ready; for (`$i=0; `$i -lt 100 -and -not (Test-Path '$markerA'); `$i++) { Start-Sleep -Milliseconds 50 }; if (-not (Test-Path '$markerA')) { exit 4 }"},
        @{id='join';title='Join';type='barrier';asset='crow-testing';dependencies=@('a','b')}
    )
    $res = Invoke-TestGraph $runtime 0
    Assert-Condition ($res.NodeStates[2].StartTime -ge $res.NodeStates[0].EndTime -and $res.NodeStates[2].StartTime -ge $res.NodeStates[1].EndTime) 'Join must wait for both branches'
    $runtime.max_concurrency = 1
    $runtime.nodes[0].command = 'Start-Sleep -Milliseconds 50'
    $runtime.nodes[1].command = 'Start-Sleep -Milliseconds 50'
    $res = Invoke-TestGraph $runtime 0
    Assert-Condition ($res.NodeStates[1].StartTime -ge $res.NodeStates[0].EndTime) 'Concurrency one must serialize reads'
    $runtime.nodes[0].verifier = @{type='file_exists';target=(Join-Path $tempRoot 'missing-artifact')}
    $res = Invoke-TestGraph $runtime 1
    Assert-Condition ($res.NodeStates[0].Status -eq 'failed') 'Missing artifact must fail verification'

    # Real mutation fixture: no changes to the audited repository or its branches.
    $repo = Join-Path $tempRoot 'repo'
    $tree = Join-Path $tempRoot 'tree'
    $null = & git init -q $repo
    Set-Content (Join-Path $repo 'allowed.txt') 'baseline'
    $null = & git -C $repo add .
    $null = & git -C $repo -c user.name=Test -c user.email=test@example.invalid commit -qm baseline
    $null = & git -C $repo worktree add -q --detach $tree
    $runtime.nodes = @(@{id='mutate';title='Mutation';type='mutation';asset='crow-testing';mutation_targets=@('allowed.txt');command="Set-Content allowed.txt 'changed value'"})
    $res = Invoke-TestGraph $runtime 1
    Assert-Condition ($res.Error.Contains('isolated Git worktree')) 'Mutation requires worktree'
    $res = Invoke-TestGraph $runtime 1 @('-WorktreePath', $repo)
    Assert-Condition ($res.Error.Contains('linked Git worktree')) 'Primary checkout must be rejected'
    $res = Invoke-TestGraph $runtime 0 @('-WorktreePath', $tree)
    Assert-Condition ((Get-Content (Join-Path $repo 'allowed.txt')) -eq 'baseline') 'Primary checkout must remain unchanged'
    $null = & git -C $tree reset --hard -q HEAD
    # Ordered writers own different files; the first writer's diff must not count against the second.
    $runtime.nodes += @{id='second';title='Second';type='mutation';asset='crow-testing';dependencies=@('mutate');mutation_targets=@('second.txt');command="Set-Content second.txt 'second writer'"}
    $res = Invoke-TestGraph $runtime 0 @('-WorktreePath', $tree)
    Assert-Condition ($res.NodeStates[1].Status -eq 'succeeded') 'Transitive execution must compare changes per writer'
    $null = & git -C $tree reset --hard -q HEAD
    Remove-Item (Join-Path $tree 'second.txt')
    $runtime.nodes = @($runtime.nodes[0])
    $runtime.nodes[0].forbidden_paths = @('allowed.txt')
    $res = Invoke-TestGraph $runtime 1 @('-WorktreePath', $tree)
    Assert-Condition ($res.NodeStates[0].Error.Contains('scope violation')) 'Forbidden paths override allowed targets'
    $runtime.nodes[0].Remove('forbidden_paths')
    $null = & git -C $tree reset --hard -q HEAD
    $runtime.approval_mode = 'none'
    $res = Invoke-TestGraph $runtime 1 @('-WorktreePath', $tree)
    Assert-Condition ($res.Error.Contains('require operator approval')) 'Mutation cannot disable approval'
    $runtime.Remove('approval_mode')
    $null = & git -C $tree reset --hard -q HEAD
    $runtime.nodes[0].command = "Set-Content outside.txt 'forbidden'"
    $res = Invoke-TestGraph $runtime 1 @('-WorktreePath', $tree)
    Assert-Condition ($res.NodeStates[0].Error.Contains('scope violation')) 'Out-of-scope mutation must fail'

    Write-Host 'Crow workflow coordinator tests passed.' -ForegroundColor Green
}
finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force
    }
}

exit 0
