[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$powerShellExecutable = (Get-Process -Id $PID).Path
$validator = Join-Path $PSScriptRoot 'Test-CrowConfig.ps1'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..\..')).Path
$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) "crow-config-tests-$([guid]::NewGuid())"

function Invoke-Case {
    param(
        [string]$Name,
        [string]$Content,
        [int]$ExpectedExit
    )

    $path = Join-Path $tempRoot "$Name.config"
    [System.IO.File]::WriteAllText($path, $Content, [System.Text.UTF8Encoding]::new($false))
    $previousErrorAction = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $output = (& $powerShellExecutable -NoProfile -File $validator -ConfigPath $path 2>&1 | Out-String)
        $exitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previousErrorAction
    }
    if ($exitCode -ne $ExpectedExit) {
        throw "$Name expected exit $ExpectedExit, got $exitCode. Output: $output"
    }
    Write-Output "Passed: $Name"
}

try {
    New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
    $valid = [System.IO.File]::ReadAllText((Join-Path $repoRoot 'crow.config'))
    Invoke-Case -Name 'valid public manifest' -Content $valid -ExpectedExit 0
    Invoke-Case -Name 'url rejection' -Content ($valid + "`nnotes: https://internal.example.invalid`n") -ExpectedExit 1
    Invoke-Case -Name 'traversal rejection' -Content ($valid + "`ndocumentation:`n  - path: ../private.md`n") -ExpectedExit 1
    Invoke-Case -Name 'absolute path rejection' -Content ($valid + "`ndocumentation:`n  - path: C:\private.md`n") -ExpectedExit 1
    Invoke-Case -Name 'credential key rejection' -Content ($valid + "`ncredential:`n  token: value`n") -ExpectedExit 1
    Invoke-Case -Name 'reference format rejection' -Content ($valid + "`n  extra_ref: unresolved`n") -ExpectedExit 1
}
finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force
    }
}
