<#
.SYNOPSIS
  Extracts the previously committed business-rules-data.json from version
  control into a temporary file, preserving its exact bytes.

.DESCRIPTION
  The identifier ledger is only trustworthy when the committed data file is read
  back exactly as it was committed. Shell redirection is not safe for that:
  Windows PowerShell 5.1 writes '>' output as UTF-16 and re-encodes non-ASCII
  characters, which corrupts rule titles, reasons, and notes.

  This helper copies git's raw output stream to the destination byte for byte,
  so UTF-8 and non-ASCII content survive on every platform and shell. The
  extracted file is validated as JSON before it is published, and a failed
  extraction leaves no destination file behind.

  Only git is invoked. No package is installed, downloaded, or executed.

.PARAMETER Destination
  Path of the temporary file to write, for example
  previous-business-rules-data.json. Delete it once the run has finished; only
  docs/business-rules-data.json and the two generated documents are committed.

.PARAMETER Path
  Repository-relative path of the committed data file.

.PARAMETER Revision
  Git revision to read the file from. Defaults to HEAD.

.PARAMETER RepositoryRoot
  Repository the revision is read from. Defaults to the current directory.

.PARAMETER GitPath
  Path to a git executable. When omitted, git is discovered on PATH.

.EXAMPLE
  ./Export-PreviousBusinessRuleData.ps1 -Destination previous-business-rules-data.json

.EXAMPLE
  ./Export-PreviousBusinessRuleData.ps1 -Destination previous.json -Revision v1.4.0 -RepositoryRoot C:\repos\permit-intake
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Destination,
    [string]$Path = 'docs/business-rules-data.json',
    [string]$Revision = 'HEAD',
    [string]$RepositoryRoot = '.',
    [string]$GitPath
)

$ErrorActionPreference = 'Stop'

function Resolve-GitExecutable {
    param([string]$RequestedPath)

    if (-not [string]::IsNullOrWhiteSpace($RequestedPath)) {
        if (Test-Path -LiteralPath $RequestedPath -PathType Leaf) {
            return (Resolve-Path -LiteralPath $RequestedPath).Path
        }
        throw "-GitPath '$RequestedPath' does not exist."
    }

    $candidate = @(Get-Command 'git' -CommandType Application -ErrorAction SilentlyContinue)
    if ($candidate.Count -gt 0) { return $candidate[0].Source }
    throw ('git was not found on PATH. Install git or pass -GitPath <path to git>. ' +
        'No file was written.')
}

function ConvertTo-ProcessArgument {
    <#
    .SYNOPSIS
      Quotes one argument using the backslash and quote rules that both Windows
      and .NET apply when a command line is turned back into an argument list.
    #>
    param([Parameter(Mandatory)][string]$Value)

    if ($Value -notmatch '[\s"]') { return $Value }

    $builder = New-Object System.Text.StringBuilder
    [void]$builder.Append('"')
    $backslashes = 0
    foreach ($character in $Value.ToCharArray()) {
        if ($character -eq '\') {
            $backslashes++
            [void]$builder.Append($character)
            continue
        }
        if ($character -eq '"') {
            # Backslashes are only special before a quote, where the run must be
            # doubled and the quote itself escaped.
            [void]$builder.Append('\' * $backslashes)
            [void]$builder.Append('\"')
        }
        else {
            [void]$builder.Append($character)
        }
        $backslashes = 0
    }
    [void]$builder.Append('\' * $backslashes)
    [void]$builder.Append('"')
    return $builder.ToString()
}

$stagingPath = $null
try {
    foreach ($option in @(
            @{ Name = 'Revision'; Value = $Revision },
            @{ Name = 'Path'; Value = $Path })) {
        if ([string]::IsNullOrWhiteSpace($option.Value) -or $option.Value.StartsWith('-')) {
            throw "-$($option.Name) must be a value, not a command-line option: '$($option.Value)'."
        }
    }
    if (-not (Test-Path -LiteralPath $RepositoryRoot -PathType Container)) {
        throw "-RepositoryRoot '$RepositoryRoot' is not a directory."
    }
    if (Test-Path -LiteralPath $Destination -PathType Container) {
        throw "-Destination '$Destination' is a directory."
    }
    $destinationDirectory = Split-Path -Parent $Destination
    if ($destinationDirectory -and -not (Test-Path -LiteralPath $destinationDirectory)) {
        throw "The destination directory does not exist: $destinationDirectory"
    }

    $gitExecutable = Resolve-GitExecutable -RequestedPath $GitPath
    $repositoryPath = (Resolve-Path -LiteralPath $RepositoryRoot).Path
    $arguments = @('-C', $repositoryPath, 'show', "${Revision}:${Path}")

    $startInfo = New-Object System.Diagnostics.ProcessStartInfo
    $startInfo.FileName = $gitExecutable
    $startInfo.Arguments = (@($arguments | ForEach-Object { ConvertTo-ProcessArgument $_ }) -join ' ')
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    # Only stdout is redirected, and it is copied as bytes rather than decoded
    # text. git's diagnostics stay on the inherited stderr, so no output is
    # re-encoded and the pipe cannot deadlock.
    $startInfo.RedirectStandardOutput = $true

    $stagingPath = "$Destination.$([guid]::NewGuid().ToString('N')).tmp"
    $process = [System.Diagnostics.Process]::Start($startInfo)
    try {
        $stream = [System.IO.File]::Open(
            $stagingPath,
            [System.IO.FileMode]::Create,
            [System.IO.FileAccess]::Write,
            [System.IO.FileShare]::None)
        try {
            $process.StandardOutput.BaseStream.CopyTo($stream)
        }
        finally {
            $stream.Dispose()
        }
        $process.WaitForExit()
        $exitCode = $process.ExitCode
    }
    finally {
        $process.Dispose()
    }

    if ($exitCode -ne 0) {
        throw ("git could not read '${Revision}:${Path}' (exit code $exitCode). " +
            'Check the revision and the repository-relative path. No file was written.')
    }

    $extracted = [System.IO.File]::ReadAllText($stagingPath)
    if ([string]::IsNullOrWhiteSpace($extracted)) {
        throw "git returned no content for '${Revision}:${Path}'. No file was written."
    }
    try {
        $extracted | ConvertFrom-Json | Out-Null
    }
    catch {
        throw ("The extracted '${Revision}:${Path}' is not valid JSON: $($_.Exception.Message). " +
            'No file was written.')
    }

    if (Test-Path -LiteralPath $Destination -PathType Leaf) {
        [System.IO.File]::Delete($Destination)
    }
    [System.IO.File]::Move($stagingPath, $Destination)
    $stagingPath = $null

    Write-Host "Extracted ${Revision}:${Path} to $Destination"
    exit 0
}
catch {
    Write-Error $_.Exception.Message -ErrorAction Continue
    exit 1
}
finally {
    if ($stagingPath -and (Test-Path -LiteralPath $stagingPath -PathType Leaf)) {
        Remove-Item -LiteralPath $stagingPath -Force -ErrorAction SilentlyContinue
    }
}
