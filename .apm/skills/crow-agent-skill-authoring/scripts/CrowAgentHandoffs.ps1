function ConvertFrom-FrontmatterScalar {
    param([string]$Value)

    $trimmed = $Value.Trim()
    if ($trimmed.StartsWith("'")) {
        $match = [regex]::Match($trimmed, "^'((?:[^']|'')*)'\s*(#.*)?$")
        if (-not $match.Success) {
            return $null
        }
        return [pscustomobject]@{ Value = $match.Groups[1].Value.Replace("''", "'"); Quoted = $true }
    }
    if ($trimmed.StartsWith('"')) {
        $match = [regex]::Match($trimmed, '^"((?:[^"\\]|\\.)*)"\s*(#.*)?$')
        if (-not $match.Success) {
            return $null
        }
        return [pscustomobject]@{ Value = [regex]::Unescape($match.Groups[1].Value); Quoted = $true }
    }
    if ($trimmed.Length -eq 0 -or $trimmed.StartsWith('#')) {
        # YAML treats an empty or comment-only value as null.
        return [pscustomobject]@{ Value = ''; Quoted = $false }
    }
    if ($trimmed -match '^([>|\[{&*!%@`]|[-?:](\s|$))') {
        return $null
    }
    $plain = ($trimmed -replace '\s+#.*$', '').TrimEnd()
    if ($plain -match ':(\s|$)') {
        # An unquoted ': ' is not a valid plain scalar in a block mapping.
        return $null
    }
    return [pscustomobject]@{ Value = $plain; Quoted = $false }
}

function Get-AgentHandoffs {
    param([string]$Path)

    # Supports the block-list form documented in interaction-contracts.md and
    # reports any other form instead of silently skipping validation.
    $lines = [System.IO.File]::ReadAllLines($Path)
    $handoffs = [System.Collections.Generic.List[hashtable]]::new()
    $errors = [System.Collections.Generic.List[string]]::new()
    $inHandoffs = $false
    $current = $null
    for ($index = 1; $index -lt $lines.Count; $index++) {
        $line = $lines[$index]
        $lineNumber = $index + 1
        if ($line.Trim() -eq '---') {
            break
        }
        if ($line -match '^(?:handoffs|''handoffs''|"handoffs")[ \t]*:(.*)$') {
            $inHandoffs = $true
            if (($Matches[1] -replace '\s*#.*$', '').Trim().Length -gt 0) {
                $errors.Add("line ${lineNumber}: handoffs must use a block list of single-line entries.")
            }
            continue
        }
        if (-not $inHandoffs -or $line.Trim().Length -eq 0 -or $line -match '^\s*#') {
            continue
        }
        if ($line -match '^\s*-\s+([\w-]+):\s*(.*)$') {
            $current = @{}
            $handoffs.Add($current)
        }
        elseif ($line -match '^[^\s#-]') {
            break
        }
        elseif (-not ($null -ne $current -and $line -match '^\s+([\w-]+):\s*(.*)$')) {
            $errors.Add("line ${lineNumber}: unsupported handoff syntax; use '- label:' entries with single-line values.")
            continue
        }
        $key = $Matches[1]
        $scalar = ConvertFrom-FrontmatterScalar $Matches[2]
        if ($null -eq $scalar) {
            $errors.Add("line ${lineNumber}: handoff '$key' must be a single-line value; quote values that contain ': '.")
            continue
        }
        $current[$key] = $scalar
    }
    return [pscustomobject]@{ Handoffs = $handoffs.ToArray(); Errors = $errors.ToArray() }
}
