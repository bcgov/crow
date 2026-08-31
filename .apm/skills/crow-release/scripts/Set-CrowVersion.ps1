[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [ValidateSet('Patch', 'Minor', 'Major')]
    [string]$Bump,

    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..\..')).Path,

    [switch]$ConfirmMajor
)

$ErrorActionPreference = 'Stop'

function Write-Utf8NoBom {
    param(
        [string]$Path,
        [string]$Content
    )

    $encoding = [System.Text.UTF8Encoding]::new($false)
    [System.IO.File]::WriteAllText($Path, $Content, $encoding)
}

$root = (Resolve-Path $RepoRoot).Path
$apmPath = Join-Path $root 'apm.yml'
$pluginPath = Join-Path $root '.github\plugin\plugin.json'
$readmePath = Join-Path $root 'README.md'

$apmContent = [System.IO.File]::ReadAllText($apmPath)
if ($apmContent -notmatch '(?m)^version:\s*([0-9]+)\.([0-9]+)\.([0-9]+)\s*$') {
    throw 'apm.yml does not contain a supported semantic version.'
}

$major = [int]$Matches[1]
$minor = [int]$Matches[2]
$patch = [int]$Matches[3]
$currentVersion = "$major.$minor.$patch"

switch ($Bump) {
    'Patch' { $patch++ }
    'Minor' {
        $minor++
        $patch = 0
    }
    'Major' {
        if (-not $ConfirmMajor) {
            throw 'A major release requires an explicit user decision and the -ConfirmMajor switch.'
        }
        $major++
        $minor = 0
        $patch = 0
    }
}

$newVersion = "$major.$minor.$patch"
$pluginContent = [System.IO.File]::ReadAllText($pluginPath)
$readmeContent = [System.IO.File]::ReadAllText($readmePath)

if ($pluginContent -notmatch '"version"\s*:\s*"' + [regex]::Escape($currentVersion) + '"') {
    throw "plugin.json does not contain the current version $currentVersion."
}
if (-not $readmeContent.Contains($currentVersion)) {
    throw "README.md does not contain the current version $currentVersion."
}

$apmVersionPattern = [regex]::new(
    '(?m)^version:\s*' + [regex]::Escape($currentVersion) + '\s*$')
$pluginVersionPattern = [regex]::new(
    '("version"\s*:\s*")' + [regex]::Escape($currentVersion) + '(")')
$updatedApm = $apmVersionPattern.Replace($apmContent, "version: $newVersion", 1)
$updatedPlugin = $pluginVersionPattern.Replace(
    $pluginContent,
    "`${1}$newVersion`${2}",
    1)
$readmeVersionPattern = [regex]::new(
    '(?<![0-9])' + [regex]::Escape($currentVersion) + '(?![0-9])')
$updatedReadme = $readmeVersionPattern.Replace($readmeContent, $newVersion)

if ($PSCmdlet.ShouldProcess($root, "Update Crow version from $currentVersion to $newVersion")) {
    Write-Utf8NoBom $apmPath $updatedApm
    Write-Utf8NoBom $pluginPath $updatedPlugin
    Write-Utf8NoBom $readmePath $updatedReadme
}

[pscustomobject]@{
    PreviousVersion = $currentVersion
    Version = $newVersion
    Bump = $Bump
}
