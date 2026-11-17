# Shared reader for Crow's deliberately constrained, explicit collection YAML.
# Fail closed on unrecognized dependency syntax; do not interpret YAML aliases,
# inline maps, duplicate keys, alternate sources, or skill-selection filters.
function Read-CrowCollectionManifest {
    param([Parameter(Mandatory)][string]$Path)

    $content = [System.IO.File]::ReadAllText($Path)
    $errors = [System.Collections.Generic.List[string]]::new()
    $fields = @{}
    $dependencies = [System.Collections.Generic.List[object]]::new()
    $inDependencies = $false
    $hasApm = $false
    $current = $null
    $section = ''
    $authorFields = @{}
    foreach ($line in ($content -split '\r?\n')) {
        if ($line -match '^\s*(#.*)?$') { continue }
        if ($line -match '^([a-zA-Z][a-zA-Z0-9_-]*):\s*(.*?)\s*$') {
            $key = $Matches[1]
            $value = $Matches[2]
            if ($fields.ContainsKey($key)) {
                $errors.Add("${Path}: duplicate manifest field '$key'.")
            }
            $fields[$key] = $value
            $section = $key
            $inDependencies = $key -ceq 'dependencies'
            if ($inDependencies -and $value.Length -gt 0) {
                $errors.Add("${Path}: dependencies must use an explicit apm list.")
            }
            if ($key -cin @('author', 'keywords') -and $value.Length -gt 0) {
                $errors.Add("${Path}: '$key' must use its explicit block form.")
            }
            continue
        }
        if (-not $inDependencies) {
            if ($section -ceq 'author' -and $line -cmatch '^  (name|email|url): ([^\r\n]+)$') {
                $key = $Matches[1]
                $value = $Matches[2].Trim()
                if ($authorFields.ContainsKey($key)) { $errors.Add("${Path}: duplicate author field '$key'.") }
                if ($value -cmatch '^[&*!|>{\[''"]|:\s|(?:^|\s)#') {
                    $errors.Add("${Path}: unsupported author scalar syntax '$value'.")
                }
                $authorFields[$key] = $value
            }
            elseif ($section -ceq 'keywords' -and $line -cmatch '^  - [a-z0-9][a-z0-9-]*\s*$') {
                # Only plain, canonical keyword entries are supported.
            }
            else { $errors.Add("${Path}: unsupported manifest syntax '$($line.Trim())'.") }
            continue
        }
        if ($line -ceq '  apm:') {
            if ($hasApm) { $errors.Add("${Path}: duplicate apm dependency list.") }
            $hasApm = $true
            $current = $null
        }
        elseif ($hasApm -and $line -cmatch '^    - git: ([^\s#]+)\s*$') {
            $current = @{ git = $Matches[1] }
            $dependencies.Add($current)
        }
        elseif ($null -ne $current -and $line -cmatch '^      (path|ref): ([^\s#]+)\s*$') {
            $key = $Matches[1]
            $value = $Matches[2]
            if ($current.ContainsKey($key)) {
                $errors.Add("${Path}: duplicate dependency field '$key'.")
            }
            $current[$key] = $value
        }
        else {
            $errors.Add("${Path}: unsupported dependency syntax '$($line.Trim())'.")
        }
    }
    if (-not $fields.ContainsKey('dependencies') -or -not $hasApm) {
        $errors.Add("${Path}: explicit apm dependencies are missing.")
    }
    return [pscustomobject]@{
        Fields = $fields
        Dependencies = @($dependencies)
        Errors = @($errors)
    }
}

function Get-CrowRootPublicationPaths {
    param([Parameter(Mandatory)][string]$Content)

    $includes = [regex]::Match($Content, '(?m)^includes:\s*\r?\n(?<body>(?:[ \t]+[^\r\n]*\r?\n?)+)')
    if ($includes.Success) {
        foreach ($match in [regex]::Matches($includes.Groups['body'].Value, '(?m)^  - (\.apm/[^\s#]+)\s*$')) {
            $match.Groups[1].Value.TrimEnd('/')
        }
    }
}

function Test-CrowFullRootDependency {
    param(
        [System.Collections.IDictionary]$Dependency,
        [string]$Version,
        [string]$Path
    )

    if ($Dependency['git'] -cne 'https://github.com/bcgov/crow.git') {
        "${Path}: full-root dependency source must be https://github.com/bcgov/crow.git."
    }
    if ($Dependency.Contains('path')) {
        "${Path}: full-root dependency must not declare a path or subset."
    }
    if ($Dependency['ref'] -cne "v$Version") {
        "${Path}: full-root dependency ref must match v$Version."
    }
}

function Read-CrowFullRootPackage {
    param([Parameter(Mandatory)][string]$RepoRoot)

    $errors = [System.Collections.Generic.List[string]]::new()
    $rootPath = Join-Path $RepoRoot 'apm.yml'
    $version = ''
    $includes = @()
    if (-not (Test-Path -LiteralPath $rootPath -PathType Leaf)) {
        $errors.Add('Full root package apm.yml is missing.')
    }
    else {
        $content = [System.IO.File]::ReadAllText($rootPath)
        $versions = [regex]::Matches($content, '(?m)^version: ([0-9]+\.[0-9]+\.[0-9]+)\s*$')
        if ($versions.Count -ne 1) { $errors.Add('Full root package must declare one semantic version.') }
        else { $version = $versions[0].Groups[1].Value }
        $names = [regex]::Matches($content, '(?m)^name:\s*([^\r\n]+)')
        if ($names.Count -ne 1 -or $names[0].Groups[1].Value.Trim() -cne 'bcgov-crow') {
            $errors.Add('Full root package identity must be bcgov-crow.')
        }
        $dependencyKeys = [regex]::Matches($content, '(?m)^(?:devDependencies|dependencies):')
        if ($dependencyKeys.Count -ne 1 -or $content -cnotmatch '(?m)^dependencies: \{\}\s*$') {
            $errors.Add('Full root package must declare dependencies: {} (no wrapper cycle).')
        }
        $includes = @(Get-CrowRootPublicationPaths -Content $content)
        if ($includes.Count -eq 0 -or [regex]::Matches($content, '(?m)^includes:').Count -ne 1) {
            $errors.Add('Full root package needs one explicit publication allowlist.')
        }
        foreach ($path in $includes) {
            if ($path -match '(^|/)\.\.?(/|$)' -or $path.Contains('\')) {
                $errors.Add("Full root publication path '$path' must be canonical, without traversal.")
            }
        }
    }
    return [pscustomobject]@{ Version = $version; Includes = $includes; Errors = @($errors) }
}

function Get-CrowCollectionCompatibilityReport {
    param([Parameter(Mandatory)][string]$RepoRoot)

    $errors = [System.Collections.Generic.List[string]]::new()
    $manifests = @{}
    $expected = @('security-remediation', 'starter-package')
    $collectionsPath = Join-Path $RepoRoot 'collections'
    $directories = @()
    if (Test-Path -LiteralPath $collectionsPath -PathType Container) {
        $directories = @(Get-ChildItem -LiteralPath $collectionsPath -Directory -Force)
        $extraFiles = @(Get-ChildItem -LiteralPath $collectionsPath -File -Force)
        if ($extraFiles.Count -gt 0) {
            $errors.Add('The collections directory may contain only the two compatibility wrappers.')
        }
    }
    $actual = @($directories | ForEach-Object { $_.Name })
    if ($actual.Count -ne 2 -or @($actual | Where-Object { $_ -cnotin $expected }).Count -gt 0 -or
        @($expected | Where-Object { $_ -cnotin $actual }).Count -gt 0) {
        $errors.Add('Exactly two compatibility wrappers are required: security-remediation and starter-package.')
    }

    $rootPackage = Read-CrowFullRootPackage -RepoRoot $RepoRoot
    foreach ($errorText in $rootPackage.Errors) { $errors.Add($errorText) }
    $version = $rootPackage.Version

    foreach ($directory in $directories) {
        if ($directory.Name -cnotin $expected) { continue }
        $entries = @(Get-ChildItem -LiteralPath $directory.FullName -Force)
        if ($entries.Count -ne 2 -or @($entries | Where-Object {
            $_.PSIsContainer -or $_.Name -cnotin @('apm.yml', 'README.md')
        }).Count -gt 0) {
            $errors.Add("$($directory.FullName): wrapper may contain only apm.yml and README.md, no own assets.")
        }
        $manifestPath = Join-Path $directory.FullName 'apm.yml'
        $readmePath = Join-Path $directory.FullName 'README.md'
        if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
            $errors.Add("${manifestPath}: wrapper manifest is missing.")
            continue
        }
        $manifest = Read-CrowCollectionManifest -Path $manifestPath
        $manifests[$directory.Name] = $manifest
        foreach ($errorText in $manifest.Errors) { $errors.Add($errorText) }
        foreach ($key in $manifest.Fields.Keys) {
            if ($key -cnotin @('name', 'version', 'description', 'author', 'license', 'repository', 'keywords', 'dependencies')) {
                $errors.Add("${manifestPath}: wrapper must not declare '$key' or publication subsets.")
            }
        }
        if ($manifest.Fields['name'] -cne "bcgov-crow-$($directory.Name)") {
            $errors.Add("${manifestPath}: wrapper identity must be bcgov-crow-$($directory.Name).")
        }
        if ($manifest.Fields['version'] -cne $version) {
            $errors.Add("${manifestPath}: wrapper version must match root version $version.")
        }
        if ($manifest.Dependencies.Count -ne 1) {
            $errors.Add("${manifestPath}: wrapper must have exactly one full-root dependency.")
        }
        foreach ($dependency in $manifest.Dependencies) {
            foreach ($errorText in Test-CrowFullRootDependency -Dependency $dependency -Version $version -Path $manifestPath) {
                $errors.Add($errorText)
            }
        }
        if (-not (Test-Path -LiteralPath $readmePath -PathType Leaf)) {
            $errors.Add("${readmePath}: wrapper README is missing.")
        }
        else {
            $readme = [System.IO.File]::ReadAllText($readmePath)
            foreach ($reference in @("bcgov/crow/collections/$($directory.Name)#v$version", 'bcgov/crow#stable')) {
                if (-not $readme.Contains($reference)) {
                    $errors.Add("${readmePath}: install documentation must reference $reference.")
                }
            }
        }
    }
    return [pscustomobject]@{
        Manifests = $manifests
        RootPackage = $rootPackage
        Version = $version
        Errors = @($errors)
    }
}
