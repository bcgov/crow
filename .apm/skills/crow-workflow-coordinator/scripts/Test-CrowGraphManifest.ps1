<#
.SYNOPSIS
    Validates a Crow dependency graph manifest (DAG).
.DESCRIPTION
    Ensures graph manifest adheres to topology rules:
    - Required schema fields present
    - No duplicate node IDs
    - No undefined dependency references
    - Strictly acyclic (no cycles)
    - Single-writer mutation constraints
.PARAMETER ManifestPath
    Path to the graph-manifest.json file.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ManifestPath
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $ManifestPath -PathType Leaf)) {
    Write-Error "Manifest file not found: $ManifestPath"
    exit 1
}

$errors = [System.Collections.Generic.List[string]]::new()

try {
    $content = Get-Content -LiteralPath $ManifestPath -Raw -Encoding UTF8
    $manifest = $content | ConvertFrom-Json
}
catch {
    Write-Error "Invalid JSON in manifest file: $($_.Exception.Message)"
    exit 1
}

# Validate the same schema published for manifest authors before inspecting topology.
$schemaPath = Join-Path $PSScriptRoot '../references/graph-manifest-schema.json'
if (-not (Test-Json -Json $content -SchemaFile $schemaPath -ErrorAction SilentlyContinue)) {
    Write-Warning 'Manifest does not conform to graph-manifest-schema.json.'
    exit 1
}

# 1. Required top-level fields
$requiredFields = @('version', 'graph_id', 'title')
foreach ($field in $requiredFields) {
    if (-not $manifest.PSObject.Properties[$field] -or [string]::IsNullOrWhiteSpace($manifest.$field)) {
        $errors.Add("Missing required top-level field: $field")
    }
}

if (-not $manifest.PSObject.Properties['nodes'] -or $null -eq $manifest.nodes -or @($manifest.nodes).Count -eq 0) {
    $errors.Add("Manifest must declare at least one node in 'nodes' array.")
    $manifestNodes = @()
}
else {
    $manifestNodes = @($manifest.nodes)
}

# 2. Duplicate node IDs and required node properties
$nodeIds = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
$nodeMap = @{}

foreach ($node in $manifestNodes) {
    if ([string]::IsNullOrWhiteSpace($node.id)) {
        $errors.Add("Node is missing required 'id' field.")
        continue
    }

    if (-not $nodeIds.Add($node.id)) {
        $errors.Add("Duplicate node ID detected: '$($node.id)'")
    }

    if ([string]::IsNullOrWhiteSpace($node.asset)) {
        $errors.Add("Node '$($node.id)' is missing required 'asset' field.")
    }

    if ([string]::IsNullOrWhiteSpace($node.type)) {
        $errors.Add("Node '$($node.id)' is missing required 'type' field.")
    }
    elseif ($node.type -notin @('read_only', 'mutation', 'verification', 'barrier')) {
        $errors.Add("Node '$($node.id)' has invalid type '$($node.type)'. Must be read_only, mutation, verification, or barrier.")
    }

    $assetRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    $agentRoot = Join-Path (Split-Path $assetRoot -Parent) 'agents'
    if ($node.asset -notmatch '^crow-[a-z0-9-]+$' -or
        (-not (Test-Path -LiteralPath (Join-Path $assetRoot "$($node.asset)/SKILL.md") -PathType Leaf) -and
         -not (Test-Path -LiteralPath (Join-Path $agentRoot "$($node.asset).agent.md") -PathType Leaf))) {
        $errors.Add("Node '$($node.id)' references unknown Crow asset '$($node.asset)'.")
    }
    if ($node.type -eq 'mutation' -and ($null -eq $node.mutation_targets -or @($node.mutation_targets).Count -eq 0)) {
        $errors.Add("Mutation node '$($node.id)' must declare mutation_targets.")
    }
    foreach ($path in @($node.mutation_targets) + @($node.forbidden_paths)) {
        if ($null -ne $path -and ($path -notmatch '^[^:*?\\]+$' -or
            [IO.Path]::IsPathRooted($path) -or $path -match '(^|/)\.\.(/|$)|(^|/)\.git(/|$)|^\./|//|^$')) {
            $errors.Add("Node '$($node.id)' has unsafe scope path '$path'; use repository-relative literal paths.")
        }
    }
    $nodeMap[$node.id] = $node
}

# 3. Undefined dependency references
foreach ($node in $manifestNodes) {
    if ($null -ne $node.dependencies) {
        foreach ($dep in $node.dependencies) {
            if (-not $nodeIds.Contains($dep)) {
                $errors.Add("Node '$($node.id)' references undefined dependency '$dep'.")
            }
        }
    }
}

# 4. Cycle detection using Kahn's algorithm (topological sort)
if ($errors.Count -eq 0 -and $manifestNodes.Count -gt 0) {
    $inDegree = @{}
    $adjacency = @{}

    foreach ($id in $nodeIds) {
        $inDegree[$id] = 0
        $adjacency[$id] = [System.Collections.Generic.List[string]]::new()
    }

    foreach ($node in $manifestNodes) {
        $deps = if ($null -ne $node.dependencies) { @($node.dependencies) } else { @() }
        $inDegree[$node.id] = $deps.Count
        foreach ($dep in $deps) {
            $adjacency[$dep].Add($node.id)
        }
    }

    $queue = [System.Collections.Generic.Queue[string]]::new()
    foreach ($id in $nodeIds) {
        if ($inDegree[$id] -eq 0) {
            $queue.Enqueue($id)
        }
    }

    $visitedCount = 0
    while ($queue.Count -gt 0) {
        $curr = $queue.Dequeue()
        $visitedCount++

        foreach ($neighbor in $adjacency[$curr]) {
            $inDegree[$neighbor]--
            if ($inDegree[$neighbor] -eq 0) {
                $queue.Enqueue($neighbor)
            }
        }
    }

    if ($visitedCount -ne $nodeIds.Count) {
        $errors.Add("Circular dependency detected in graph manifest (cycle exists).")
    }
}

# 5. Single-writer mutation check
if ($errors.Count -eq 0) {
    $mutationNodes = @($manifestNodes | Where-Object { $_.type -eq 'mutation' })
    if ($mutationNodes.Count -gt 1) {
        # Helper to check if node B is reachable from node A (A is an ancestor of B)
        function Test-Reachable($startId, $targetId) {
            $visited = [System.Collections.Generic.HashSet[string]]::new()
            $dfsQueue = [System.Collections.Generic.Queue[string]]::new()
            $dfsQueue.Enqueue($startId)

            while ($dfsQueue.Count -gt 0) {
                $curr = $dfsQueue.Dequeue()
                if ($curr -eq $targetId) { return $true }
                if ($visited.Add($curr)) {
                    foreach ($next in $adjacency[$curr]) {
                        $dfsQueue.Enqueue($next)
                    }
                }
            }
            return $false
        }

        for ($i = 0; $i -lt $mutationNodes.Count; $i++) {
            for ($j = $i + 1; $j -lt $mutationNodes.Count; $j++) {
                $nodeA = $mutationNodes[$i].id
                $nodeB = $mutationNodes[$j].id

                $aBeforeB = Test-Reachable $nodeA $nodeB
                $bBeforeA = Test-Reachable $nodeB $nodeA

                if (-not $aBeforeB -and -not $bBeforeA) {
                    $errors.Add("Unsafe concurrent mutation detected: Mutation nodes '$nodeA' and '$nodeB' have no ordering dependency between them.")
                }
            }
        }
    }
}

# Report results
$isValid = ($errors.Count -eq 0)

if ($isValid) {
    Write-Host "Graph manifest '$($manifest.graph_id)' is VALID (Nodes: $($manifestNodes.Count))." -ForegroundColor Green
    return $true
}
else {
    Write-Warning "Graph manifest validation failed with $($errors.Count) error(s):"
    foreach ($err in $errors) {
        Write-Warning "  - $err"
    }
    if ($MyInvocation.InvocationName -ne '.') {
        exit 1
    }
    return $false
}
