$ErrorActionPreference = 'Stop'
$fixtureRoot = Join-Path ([System.IO.Path]::GetTempPath()) (
    'crow-agent-handoffs-' + [guid]::NewGuid().ToString('N'))
$utf8 = [System.Text.UTF8Encoding]::new($false)
$failures = 0

. (Join-Path $PSScriptRoot 'CrowAgentHandoffs.ps1')

function Get-FixtureResult {
    param([string]$Frontmatter)

    $path = Join-Path $fixtureRoot ([guid]::NewGuid().ToString('N') + '.agent.md')
    $content = "---`r`nname: 'Crow Fixture Agent'`r`n$Frontmatter`r`n---`r`n`r`n# Fixture`r`n"
    [System.IO.File]::WriteAllText($path, $content, $utf8)
    return Get-AgentHandoffs -Path $path
}

function Assert-Case {
    param(
        [string]$Name,
        [scriptblock]$Check
    )

    try {
        if (-not (& $Check)) {
            throw 'assertion returned false'
        }
        Write-Information -MessageData "Passed: $Name" -InformationAction Continue
    }
    catch {
        $script:failures++
        Write-Information -MessageData "FAILED: $Name - $_" -InformationAction Continue
    }
}

try {
    New-Item -ItemType Directory -Path $fixtureRoot -Force | Out-Null

    $result = Get-FixtureResult @'
handoffs:
  - label: 'Review changes'
    agent: 'Crow Code Review Agent'
    prompt: 'It''s ready # not a comment'
    send: false
  # a comment between entries
  - label: "Second"
    agent: Crow Other Agent # trailing comment
    prompt: "Say \"hi\""
    send: false
tools: ['read']
'@
    Assert-Case 'block list parses two entries' {
        $result.Errors.Count -eq 0 -and $result.Handoffs.Count -eq 2
    }
    Assert-Case 'single-quoted value keeps escaped quote and hash' {
        $result.Handoffs[0]['prompt'].Value -ceq "It's ready # not a comment"
    }
    Assert-Case 'unquoted value drops trailing comment' {
        $result.Handoffs[1]['agent'].Value -ceq 'Crow Other Agent'
    }
    Assert-Case 'double-quoted value unescapes quotes' {
        $result.Handoffs[1]['prompt'].Value -ceq 'Say "hi"'
    }
    Assert-Case 'unquoted send is not marked quoted' {
        -not $result.Handoffs[0]['send'].Quoted -and $result.Handoffs[0]['send'].Value -ceq 'false'
    }

    $result = Get-FixtureResult @'
handoffs:
- label: 'Flush'
  agent: 'Crow Code Review Agent'
  prompt: 'p'
  send: false
'@
    Assert-Case 'flush-left list is parsed' {
        $result.Errors.Count -eq 0 -and $result.Handoffs.Count -eq 1 -and
            $result.Handoffs[0]['label'].Value -ceq 'Flush'
    }

    $result = Get-FixtureResult @'
handoffs:
# column-zero comment
  - label: 'After comment'
    agent: 'Crow Code Review Agent'
    prompt: 'p'
    send: false
'@
    Assert-Case 'column-zero comment does not end the list' {
        $result.Errors.Count -eq 0 -and $result.Handoffs.Count -eq 1
    }

    $result = Get-FixtureResult "handoffs: [{label: x, agent: y}]"
    Assert-Case 'flow-style handoffs report an error' {
        $result.Errors.Count -gt 0
    }

    $result = Get-FixtureResult @'
handoffs:
  - {label: x, agent: y}
'@
    Assert-Case 'flow-style entry reports an error' {
        $result.Errors.Count -gt 0
    }

    $result = Get-FixtureResult @'
handoffs:
  - label: 'Block'
    agent: 'Crow Code Review Agent'
    prompt: >
      folded text
    send: false
'@
    Assert-Case 'block scalar reports an error' {
        $result.Errors.Count -gt 0
    }

    $result = Get-FixtureResult @'
handoffs:
  - label: 'Quoted send'
    agent: 'Crow Code Review Agent'
    prompt: 'p'
    send: 'false'
'@
    Assert-Case 'quoted send is marked quoted' {
        $result.Handoffs[0]['send'].Quoted
    }

    $result = Get-FixtureResult "tools: ['read']"
    Assert-Case 'agent without handoffs returns no entries' {
        $result.Errors.Count -eq 0 -and $result.Handoffs.Count -eq 0
    }
}
finally {
    if (Test-Path -LiteralPath $fixtureRoot) {
        Remove-Item -LiteralPath $fixtureRoot -Recurse -Force
    }
}

if ($failures -gt 0) {
    throw "$failures agent handoff parser test(s) failed."
}
Write-Information -MessageData 'All agent handoff parser tests passed.' -InformationAction Continue
exit 0
