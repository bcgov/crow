<#
.SYNOPSIS
    Deterministically selects an execution strategy for Crow agent tasks.
.DESCRIPTION
    Evaluates task parameters and selects among:
    - direct (minimal localized edit)
    - graph (multi-step DAG with dependencies)
    - bounded-loop (iterative single-task trial & test)
    - parallel-batch (bulk independent tasks)
.PARAMETER TaskDescription
    Brief description of the task.
.PARAMETER EstimatedFiles
    Estimated number of files affected.
.PARAMETER HasPrerequisites
    Switch indicating if distinct phases or dependencies exist.
.PARAMETER NeedsIterativeFeedback
    Switch indicating if the task requires iterative test-fix cycles.
.PARAMETER IsBatch
    Switch indicating if the task is identical across many independent items.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$TaskDescription,

    [ValidateRange(1, 2147483647)]
    [int]$EstimatedFiles = 1,

    [switch]$HasPrerequisites,

    [switch]$NeedsIterativeFeedback,

    [switch]$IsBatch
)

$ErrorActionPreference = 'Stop'

$strategy = 'direct'
$reason = 'Localized change without multi-agent dependencies.'
$artifact = 'Implementation notes'

if ($HasPrerequisites) {
    $strategy = 'graph'
    $reason = 'Prerequisite dependencies require ordered execution.'
    $artifact = 'graph-manifest.json'
}
elseif ($IsBatch) {
    $strategy = 'parallel-batch'
    $reason = 'Identical independent tasks partitioned across multiple items.'
    $artifact = 'Batch job list'
}
elseif ($EstimatedFiles -gt 2) {
    $strategy = 'graph'
    $reason = 'Multi-phase workflow with prerequisite dependencies or ordering barriers.'
    $artifact = 'graph-manifest.json'
}
elseif ($NeedsIterativeFeedback) {
    $strategy = 'bounded-loop'
    $reason = 'Single bounded task requiring iterative trial-and-error with a locked verifier.'
    $artifact = 'handoffs/task_packet.md'
}

$result = [PSCustomObject]@{
    Strategy           = $strategy
    Reason             = $reason
    RecommendedArtifact = $artifact
    TaskDescription    = $TaskDescription
}

if ($MyInvocation.InvocationName -ne '.') {
    $result | ConvertTo-Json -Depth 4
}
else {
    return $result
}
