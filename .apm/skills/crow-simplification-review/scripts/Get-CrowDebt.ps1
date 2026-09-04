[CmdletBinding()]
param(
    [string]$RepoRoot = (Get-Location).Path
)

$ErrorActionPreference = 'Stop'
$root = (Resolve-Path $RepoRoot).Path
$skipNames = @('.git', '.codebase-memory', '.scannerwork', 'build', 'node_modules', 'evidence')
$textExtensions = @(
    '.c', '.cc', '.cpp', '.cs', '.css', '.fs', '.fsx', '.go', '.html', '.java',
    '.js', '.json', '.jsx', '.md', '.php', '.ps1', '.py', '.razor', '.rb',
    '.rs', '.scss', '.sh', '.sql', '.ts', '.tsx', '.vb', '.vue', '.xml', '.yaml',
    '.yml'
)
$pattern = '(?i)^\s*(?:#|//|/\*|\*|<!--|;|--|'')\s*crow-debt:\s*(?<body>.+?)(?:\s*(?:-->|[*]/))?$'
$commentPattern = '(?i)(?:^\s*|[\s{(;])(?:#|//|/\*|<!--|;|--|'')\s*(?<kind>TODO|TO-DO|FIXME|HACK|XXX|FUTURE|CHANGE|NOTE)\s*:?\s*(?<body>.+?)\s*$'
$markers = [System.Collections.Generic.List[object]]::new()
$comments = [System.Collections.Generic.List[object]]::new()

$files = Get-ChildItem $root -File -Recurse | Where-Object {
    $_.Extension.ToLowerInvariant() -in $textExtensions -and
    ($_.FullName.Substring($root.Length + 1).Split([IO.Path]::DirectorySeparatorChar) |
        Where-Object { $_ -in $skipNames }).Count -eq 0
} | Sort-Object FullName

foreach ($file in $files) {
    $relative = $file.FullName.Substring($root.Length + 1).Replace('\', '/')
    if ($relative -eq 'docs/Crow-debt.md') {
        continue
    }
    $lineNumber = 0
    $inFence = $false
    foreach ($line in [IO.File]::ReadLines($file.FullName)) {
        $lineNumber++
        if ($line -match '^\s*(?:```|~~~)') {
            $inFence = -not $inFence
            continue
        }
        if ($inFence) {
            continue
        }
        $match = [regex]::Match($line, $pattern)
        if ($match.Success) {
            $body = $match.Groups['body'].Value.Trim()
            $fields = @{}
            foreach ($fieldMatch in [regex]::Matches($body, '(?i)(?:^|;)\s*(type|ceiling|revisit|owner|status)\s*:\s*([^;]+)')) {
                $value = $fieldMatch.Groups[2].Value.Trim()
                if ($value) {
                    $fields[$fieldMatch.Groups[1].Value.ToLowerInvariant()] = $value
                }
            }
            $missingMetadata = @('ceiling', 'owner') | Where-Object { -not $fields.ContainsKey($_) }
            $tag = if (-not $fields.ContainsKey('revisit')) {
                'no-trigger'
            }
            elseif ($missingMetadata.Count -gt 0) {
                'incomplete'
            }
            else {
                'tracked'
            }
            $markers.Add([pscustomobject]@{
                File = $relative
                Line = $lineNumber
                Type = if ($fields.ContainsKey('type')) { $fields.type } else { 'shortcut' }
                Body = $body
                Ceiling = if ($fields.ContainsKey('ceiling')) { $fields.ceiling } else { '' }
                Revisit = if ($fields.ContainsKey('revisit')) { $fields.revisit } else { '' }
                Owner = if ($fields.ContainsKey('owner')) { $fields.owner } else { '' }
                Status = if ($fields.ContainsKey('status')) { $fields.status } else { '' }
                Tag = $tag
            })
            continue
        }

        $commentMatch = [regex]::Match($line, $commentPattern)
        if ($commentMatch.Success) {
            $commentBody = $commentMatch.Groups['body'].Value.Trim() -replace '\s*(?:-->|[*]/)\s*$', ''
            if ($commentBody) {
                $comments.Add([pscustomobject]@{
                    File = $relative
                    Line = $lineNumber
                    Kind = $commentMatch.Groups['kind'].Value.ToUpperInvariant()
                    Body = $commentBody.Trim()
                })
            }
        }
    }
}

'Crow debt markers'
foreach ($marker in $markers) {
    '{0}:L{1} | {2} | {3} | ceiling: {4} | revisit: {5} | owner: {6} | status: {7} | {8}' -f `
        $marker.File, $marker.Line, $marker.Type, $marker.Body, $marker.Ceiling,
        $marker.Revisit, $marker.Owner, $marker.Status, $marker.Tag
}

$missingTriggerCount = @($markers | Where-Object { $_.Tag -eq 'no-trigger' }).Count
$incompleteCount = @($markers | Where-Object { $_.Tag -eq 'incomplete' }).Count
if ($markers.Count -eq 0) {
    'No crow-debt markers. Clean ledger.'
}
else {
    '{0} markers, {1} without a revisit trigger, {2} with incomplete ceiling or owner metadata.' -f `
        $markers.Count, $missingTriggerCount, $incompleteCount
}

''
'General debt comments'
foreach ($comment in $comments) {
    '{0}:L{1} | {2} | {3}' -f $comment.File, $comment.Line, $comment.Kind, $comment.Body
}
if ($comments.Count -eq 0) {
    'No general debt comments found.'
}
else {
    '{0} general debt comments found.' -f $comments.Count
}
