[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$RepoRoot,

    [Parameter(Mandatory)]
    [string]$OutputPath
)

$ErrorActionPreference = 'Stop'
$root = (Resolve-Path -LiteralPath $RepoRoot).Path
$candidatePaths = [System.Collections.Generic.List[string]]::new()
$scope = 'FilesystemCandidates'

$gitPatterns = @(
    '.github/workflows/*.yml',
    '.github/workflows/*.yaml',
    'azure-pipelines*.yml',
    'azure-pipelines*.yaml',
    '.gitlab-ci.yml',
    'Jenkinsfile')
$previousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = 'Continue'
try {
    $gitRoot = (& git -C $root rev-parse --show-toplevel 2>$null)
    $gitAvailable = $LASTEXITCODE -eq 0
}
finally {
    $ErrorActionPreference = $previousErrorActionPreference
}

if ($gitAvailable) {
    $gitArguments = @('-C', $root, 'ls-files', '--') + $gitPatterns
    $trackedPaths = @(& git @gitArguments)
    if ($LASTEXITCODE -ne 0) {
        throw 'Unable to enumerate tracked pipeline files with Git.'
    }
    foreach ($trackedPath in $trackedPaths) {
        $resolvedPath = Join-Path $root ([string]$trackedPath)
        if (Test-Path -LiteralPath $resolvedPath -PathType Leaf) {
            $candidatePaths.Add((Resolve-Path -LiteralPath $resolvedPath).Path)
        }
    }
    $scope = 'TrackedPipelineFiles'
}
else {
    foreach ($relativePattern in @(
        '.github\workflows\*.yml',
        '.github\workflows\*.yaml',
        'azure-pipelines*.yml',
        'azure-pipelines*.yaml',
        '.gitlab-ci.yml',
        'Jenkinsfile')) {
        foreach ($file in @(Get-ChildItem -Path (Join-Path $root $relativePattern) -File -ErrorAction SilentlyContinue)) {
            if (-not $candidatePaths.Contains($file.FullName)) {
                $candidatePaths.Add($file.FullName)
            }
        }
    }
}

function Get-ExecutablePipelineText {
    param([string]$Path)

    $fileContent = [System.IO.File]::ReadAllText($Path)
    if ([System.IO.Path]::GetFileName($Path) -eq 'Jenkinsfile') {
        return $fileContent
    }

    $lines = @($fileContent -split '\r?\n')
    $commands = [System.Collections.Generic.List[string]]::new()
    for ($index = 0; $index -lt $lines.Count; $index++) {
        $line = $lines[$index]
        $match = [regex]::Match(
            $line,
            '^(?<indent>\s*)(?:-\s*)?(?<key>run|script|uses|task|bash|pwsh|powershell|sh|command):\s*(?<value>.*)$',
            [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
        if (-not $match.Success) {
            continue
        }

        $indentLength = $match.Groups['indent'].Value.Length
        $value = $match.Groups['value'].Value.Trim()
        if ($value -notin @('', '|', '>', '|-', '>-')) {
            $commands.Add($value)
        }
        for ($childIndex = $index + 1; $childIndex -lt $lines.Count; $childIndex++) {
            $childLine = $lines[$childIndex]
            if ([string]::IsNullOrWhiteSpace($childLine)) {
                continue
            }
            $childIndent = $childLine.Length - $childLine.TrimStart().Length
            if ($childIndent -le $indentLength) {
                break
            }
            $trimmed = $childLine.Trim()
            if (-not $trimmed.StartsWith('#')) {
                $commands.Add($trimmed)
            }
            $index = $childIndex
        }
    }
    return $commands -join [Environment]::NewLine
}

$executableByPath = @{}
foreach ($path in $candidatePaths) {
    $executableByPath[$path] = Get-ExecutablePipelineText $path
}
$content = @($executableByPath.Values) -join [Environment]::NewLine

$gatePatterns = [ordered]@{
    sast = '(?i)\b(codeql|semgrep|sonar(?:qube|cloud)?|sast)\b'
    sca = '(?i)\b(dependency-check|dotnet\s+list\s+.+--vulnerable|npm\s+audit|pnpm\s+audit|yarn\s+audit|snyk\s+test|osv-scanner)\b'
    secretScanning = '(?i)\b(gitleaks|trufflehog|detect-secrets|secret[- ]scann(?:er|ing))\b'
    containerScanning = '(?i)\b(trivy|grype|docker\s+scout|snyk\s+container)\b'
    coverageCollection = '(?i)\b(coverlet|cobertura|jacoco|opencover|nyc|istanbul|c8|codecov|pytest-cov|coverage\.py|xplat code coverage|phpunit)\b'
    coverageEnforcement = '(?i)(--fail-under(?:=|\s)|/p:threshold(?:=|\s)|\b(?:nyc|c8)\s+check-coverage\b|\bjacoco\b.*\bcheck\b|\bcoverageThreshold\b|\bminimumCoverage\b|\bphpunit\b.*--coverage-)'
}

$gates = [ordered]@{}
foreach ($entry in $gatePatterns.GetEnumerator()) {
    $gates[$entry.Key] = [ordered]@{
        candidateObserved = [regex]::IsMatch($content, [string]$entry.Value)
        scope = $scope
    }
}

$noOpCoverageCandidates = [System.Collections.Generic.List[object]]::new()
foreach ($path in $candidatePaths) {
    $fileContent = [System.IO.File]::ReadAllText($path)
    $relativePath = $path.Substring($root.Length + 1).Replace('\', '/')
    $lines = @($fileContent -split '\r?\n')
    for ($index = 0; $index -lt $lines.Count; $index++) {
        if ($lines[$index] -notmatch '(?i)^\s*(?:-\s*name|displayName):.*coverage.*(threshold|gate|verify)') {
            continue
        }
        $windowEnd = [Math]::Min($lines.Count - 1, $index + 8)
        $window = ($lines[$index..$windowEnd] -join [Environment]::NewLine)
        $hasSuccessEcho = $window -match '(?i)\b(echo|write-output)\b.*\b(success|verified|pass)'
        $hasEnforcement = $window -match $gatePatterns.coverageEnforcement
        if ($hasSuccessEcho -and -not $hasEnforcement) {
            $noOpCoverageCandidates.Add([ordered]@{
                path = $relativePath
                line = $index + 1
                reason = 'Coverage gate name is followed by a success-only output with no observed threshold command.'
            })
        }
    }
}

$result = [ordered]@{
    schemaVersion = '1.0'
    inspectedFiles = @(
        $candidatePaths |
            ForEach-Object { $_.Substring($root.Length + 1).Replace('\', '/') }
    )
    gates = $gates
    candidates = [ordered]@{
        noOpCoverage = @($noOpCoverageCandidates)
    }
    limitations = @(
        "Absence applies only to the reported '$scope' scope.",
        'Organization, repository-host, inherited-template, and deployment-platform controls require separate verification.',
        'Candidate patterns are not proof of an enforcing gate and require semantic review before becoming findings.'
    )
}

$outputDirectory = Split-Path -Parent $OutputPath
if (-not [string]::IsNullOrWhiteSpace($outputDirectory)) {
    [System.IO.Directory]::CreateDirectory(
        [System.IO.Path]::GetFullPath($outputDirectory)) | Out-Null
}
[System.IO.File]::WriteAllText(
    [System.IO.Path]::GetFullPath($OutputPath),
    ($result | ConvertTo-Json -Depth 10),
    [System.Text.UTF8Encoding]::new($false))

Write-Output "Crow CI security gate candidates written to $OutputPath"
