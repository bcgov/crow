function Get-CrowPathComparison {
    if ([System.IO.Path]::DirectorySeparatorChar -eq [char]92) {
        return [System.StringComparison]::OrdinalIgnoreCase
    }

    return [System.StringComparison]::Ordinal
}

function Get-CrowPathStringComparer {
    if ([System.IO.Path]::DirectorySeparatorChar -eq [char]92) {
        return [System.StringComparer]::OrdinalIgnoreCase
    }

    return [System.StringComparer]::Ordinal
}

function Get-CrowRepositoryRelativePath {
    param(
        [string]$Root,
        [string]$Path
    )

    $rootPath = [System.IO.Path]::GetFullPath($Root).TrimEnd(
        [char[]]@(
            [System.IO.Path]::DirectorySeparatorChar,
            [System.IO.Path]::AltDirectorySeparatorChar
        ))
    $fullPath = [System.IO.Path]::GetFullPath($Path)
    $rootPrefix = $rootPath + [System.IO.Path]::DirectorySeparatorChar
    if (-not $fullPath.StartsWith(
            $rootPrefix,
            (Get-CrowPathComparison))) {
        return $null
    }

    return $fullPath.Substring($rootPrefix.Length).Replace('\', '/')
}

function Get-CrowSkillRootForPath {
    param(
        [string]$RelativePath,
        [System.Collections.IDictionary]$SkillNameToRoot
    )

    $pathComparison = Get-CrowPathComparison
    foreach ($skillRoot in @($SkillNameToRoot.Values | Sort-Object Length -Descending)) {
        if ($RelativePath.Equals(
                $skillRoot,
                $pathComparison) -or
            $RelativePath.StartsWith(
                "$skillRoot/",
                $pathComparison)) {
            return $skillRoot
        }
    }

    return $null
}

function Get-CrowMarkdownContentLine {
    param([System.IO.FileInfo]$File)

    $lines = [System.IO.File]::ReadAllLines($File.FullName)
    $insideFence = $false
    $fenceCharacter = ''
    $fenceLength = 0
    $listContentIndent = $null

    for ($lineIndex = 0; $lineIndex -lt $lines.Count; $lineIndex++) {
        $line = $lines[$lineIndex]
        $scanLine = $line
        while ($true) {
            $quoteMatch = [regex]::Match($scanLine, '^\s{0,3}>\s?')
            if (-not $quoteMatch.Success) {
                break
            }
            $scanLine = $scanLine.Substring($quoteMatch.Length)
        }

        $listMatch = [regex]::Match(
            $scanLine,
            '^(?<indent> *)(?<marker>[-+*]|\d{1,9}[.)])(?<spacing>[ \t]+)(?<content>.*)$')
        $listIndent = if ($listMatch.Success) {
            $listMatch.Groups['indent'].Length
        }
        else {
            0
        }
        $isListItem = $listMatch.Success -and (
            $listIndent -lt 4 -or
            ($null -ne $listContentIndent -and
                $listIndent -lt ($listContentIndent + 4)))
        $indentedCode = $false
        if ($isListItem) {
            $listContentIndent = $listMatch.Groups['indent'].Length +
                $listMatch.Groups['marker'].Length +
                $listMatch.Groups['spacing'].Length
            $scanLine = $listMatch.Groups['content'].Value
        }
        elseif ([string]::IsNullOrWhiteSpace($scanLine)) {
            if (-not $insideFence) {
                [pscustomobject]@{
                    Text = ''
                    Line = $lineIndex + 1
                }
            }
            continue
        }
        else {
            $indentMatch = [regex]::Match($scanLine, '^(?<indent> *)(?<content>.*)$')
            $indent = $indentMatch.Groups['indent'].Length
            if ($null -ne $listContentIndent) {
                if ($indent -ge $listContentIndent) {
                    if (-not $insideFence -and $indent -ge ($listContentIndent + 4)) {
                        $indentedCode = $true
                    }
                    else {
                        $scanLine = $scanLine.Substring($listContentIndent)
                    }
                }
                else {
                    $listContentIndent = $null
                    $indentedCode = $indent -ge 4 -or $scanLine.StartsWith("`t")
                }
            }
            elseif (-not $insideFence) {
                $indentedCode = $indent -ge 4 -or $scanLine.StartsWith("`t")
            }
        }
        if ($indentedCode) {
            continue
        }

        $fenceMatch = [regex]::Match(
            $scanLine,
            '^\s{0,3}(?<fence>`{3,}|~{3,})(?<suffix>.*)$')
        if ($fenceMatch.Success) {
            $marker = $fenceMatch.Groups['fence'].Value
            if (-not $insideFence) {
                $insideFence = $true
                $fenceCharacter = $marker.Substring(0, 1)
                $fenceLength = $marker.Length
            }
            elseif ($marker.Substring(0, 1) -eq $fenceCharacter -and
                $marker.Length -ge $fenceLength -and
                [string]::IsNullOrWhiteSpace($fenceMatch.Groups['suffix'].Value)) {
                $insideFence = $false
            }
            continue
        }
        if ($insideFence) {
            continue
        }

        [pscustomobject]@{
            Text = $scanLine
            Line = $lineIndex + 1
        }
    }
}

function Get-CrowMarkdownTextWithoutInlineCode {
    param([string]$Line)

    $builder = [System.Text.StringBuilder]::new()
    $index = 0
    while ($index -lt $Line.Length) {
        if ($Line[$index] -ne '`') {
            [void]$builder.Append($Line[$index])
            $index++
            continue
        }

        $insideLinkLabel = $Line.LastIndexOf('[', $index) -gt
            $Line.LastIndexOf(']', $index)
        $delimiterLength = 1
        while ($index + $delimiterLength -lt $Line.Length -and
            $Line[$index + $delimiterLength] -eq '`') {
            $delimiterLength++
        }

        $closingIndex = -1
        $searchIndex = $index + $delimiterLength
        while ($searchIndex -lt $Line.Length) {
            if ($Line[$searchIndex] -ne '`') {
                $searchIndex++
                continue
            }

            $candidateLength = 1
            while ($searchIndex + $candidateLength -lt $Line.Length -and
                $Line[$searchIndex + $candidateLength] -eq '`') {
                $candidateLength++
            }
            if ($candidateLength -eq $delimiterLength) {
                $closingIndex = $searchIndex
                break
            }
            $searchIndex += $candidateLength
        }

        if ($closingIndex -ge 0) {
            if ($insideLinkLabel) {
                $codeSpanLength = $closingIndex + $delimiterLength - $index
                [void]$builder.Append($Line.Substring($index, $codeSpanLength))
            }
            $index = $closingIndex + $delimiterLength
            continue
        }

        for ($tick = 0; $tick -lt $delimiterLength; $tick++) {
            [void]$builder.Append('`')
        }
        $index += $delimiterLength
    }

    return $builder.ToString()
}

function Get-CrowMarkdownDestination {
    param([string]$Value)

    $destination = $Value.Trim()
    if ($destination.StartsWith('<')) {
        $closingBracket = $destination.IndexOf('>')
        if ($closingBracket -gt 0) {
            return $destination.Substring(1, $closingBracket - 1)
        }
    }

    $depth = 0
    for ($index = 0; $index -lt $destination.Length; $index++) {
        $character = $destination[$index]
        if ($character -eq '\' -and $index + 1 -lt $destination.Length) {
            $index++
            continue
        }
        if ($character -eq '(') {
            $depth++
        }
        elseif ($character -eq ')' -and $depth -gt 0) {
            $depth--
        }
        elseif ([char]::IsWhiteSpace($character) -and $depth -eq 0) {
            return $destination.Substring(0, $index)
        }
    }

    return $destination
}

function ConvertFrom-CrowMarkdownEscapedDestination {
    param([string]$Destination)

    $escapablePunctuation = '!"#$%&''()*+,-./:;<=>?@[\]^_`{|}~'
    $builder = [System.Text.StringBuilder]::new()
    for ($index = 0; $index -lt $Destination.Length; $index++) {
        if ($Destination[$index] -eq '\' -and
            $index + 1 -lt $Destination.Length -and
            $escapablePunctuation.IndexOf($Destination[$index + 1]) -ge 0) {
            [void]$builder.Append($Destination[$index + 1])
            $index++
            continue
        }
        [void]$builder.Append($Destination[$index])
    }

    return $builder.ToString()
}

function Get-CrowMarkdownLink {
    param([System.IO.FileInfo]$File)

    $inlineLinkPattern = '\[(?<label>(?:\\.|[^\[\]]|(?<LabelOpen>\[)|(?<-LabelOpen>\]))*(?(LabelOpen)(?!)))\]\((?<target><[^>]+>|(?:\\.|[^()]|(?<TargetOpen>\()|(?<-TargetOpen>\)))*(?(TargetOpen)(?!)))\)'
    $referenceDefinitionPattern = '^\s{0,3}\[(?<label>[^\]]+)\]:\s*(?<target><[^>]+>|(?:\\.|[^\s])+)(?:\s+(?:"[^"]*"|''[^'']*''|\([^)]*\)))?\s*$'
    $referenceUsePattern = '\[(?<text>[^\]]+)\](?:\[(?<label>[^\]]*)\])?'
    $sourceLines = @(Get-CrowMarkdownContentLine -File $File)
    $referenceDefinitions = @{}

    foreach ($sourceLine in $sourceLines) {
        $scanLine = Get-CrowMarkdownTextWithoutInlineCode -Line $sourceLine.Text
        $definitionMatch = [regex]::Match($scanLine, $referenceDefinitionPattern)
        if (-not $definitionMatch.Success) {
            continue
        }

        $referenceLabel = [regex]::Replace(
            $definitionMatch.Groups['label'].Value.Trim(),
            '\s+',
            ' ').ToLowerInvariant()
        if (-not $referenceDefinitions.ContainsKey($referenceLabel)) {
            $referenceDefinitions[$referenceLabel] =
                Get-CrowMarkdownDestination -Value $definitionMatch.Groups['target'].Value
        }
    }

    foreach ($sourceLine in $sourceLines) {
        $scanLine = Get-CrowMarkdownTextWithoutInlineCode -Line $sourceLine.Text
        $targets = [System.Collections.Generic.List[object]]::new()
        foreach ($linkMatch in [regex]::Matches($scanLine, $inlineLinkPattern)) {
            $targets.Add([pscustomobject]@{
                Target = Get-CrowMarkdownDestination -Value $linkMatch.Groups['target'].Value
                ReferenceLabel = ''
            })
        }

        $definitionMatch = [regex]::Match($scanLine, $referenceDefinitionPattern)
        if ($definitionMatch.Success) {
            $referenceLabel = [regex]::Replace(
                $definitionMatch.Groups['label'].Value.Trim(),
                '\s+',
                ' ').ToLowerInvariant()
            $targets.Add([pscustomobject]@{
                Target = $referenceDefinitions[$referenceLabel]
                ReferenceLabel = $referenceLabel
            })
        }
        else {
            foreach ($referenceUse in [regex]::Matches($scanLine, $referenceUsePattern)) {
                $nextCharacterIndex = $referenceUse.Index + $referenceUse.Length
                if ($nextCharacterIndex -lt $scanLine.Length -and
                    $scanLine[$nextCharacterIndex] -eq '(') {
                    continue
                }
                $referenceLabel = $referenceUse.Groups['label'].Value
                if ([string]::IsNullOrWhiteSpace($referenceLabel)) {
                    $referenceLabel = $referenceUse.Groups['text'].Value
                }
                $referenceLabel = [regex]::Replace(
                    $referenceLabel.Trim(),
                    '\s+',
                    ' ').ToLowerInvariant()
                if ($referenceDefinitions.ContainsKey($referenceLabel)) {
                    $targets.Add([pscustomobject]@{
                        Target = $referenceDefinitions[$referenceLabel]
                        ReferenceLabel = $referenceLabel
                    })
                }
            }
        }

        foreach ($targetEntry in $targets) {
            $reference = $targetEntry.Target.Trim()
            $target = ConvertFrom-CrowMarkdownEscapedDestination -Destination $reference
            $target = ($target -split '[?#]', 2)[0].Trim()

            if ([string]::IsNullOrWhiteSpace($target) -or
                $target.StartsWith('#') -or
                $target.StartsWith('//') -or
                $target -match '^[A-Za-z][A-Za-z0-9+.-]*:' -or
                $target -match '[\[\]]' -or
                $target.Contains('{{')) {
                continue
            }

            $target = [System.Uri]::UnescapeDataString($target)
            [pscustomobject]@{
                Target = $target
                Reference = $reference
                ReferenceLabel = $targetEntry.ReferenceLabel
                Line = $sourceLine.Line
            }
        }
    }
}

function Get-CrowSkillMentionFromParagraph {
    param(
        [string]$Text,
        [System.Collections.Generic.List[object]]$LineMap
    )

    $sentenceBoundaryPattern = [regex]::new('[.!?](?=\s|$)')
    foreach ($match in [regex]::Matches(
            $Text,
            '(?i)(?<![A-Za-z0-9_-])(?<name>crow-[a-z0-9]+(?:-[a-z0-9]+)*)(?![A-Za-z0-9_-])')) {
        $sentenceStart = 0
        foreach ($punctuation in $sentenceBoundaryPattern.Matches($Text)) {
            if ($punctuation.Index -ge $match.Index) {
                break
            }
            $sentenceStart = $punctuation.Index + 1
        }
        $sentenceEnd = $Text.Length
        $nextPunctuation = $sentenceBoundaryPattern.Match(
            $Text,
            $match.Index + $match.Length)
        if ($nextPunctuation.Success) {
            $sentenceEnd = $nextPunctuation.Index + 1
        }

        $sentence = $Text.Substring($sentenceStart, $sentenceEnd - $sentenceStart)
        $prefix = $Text.Substring($sentenceStart, $match.Index - $sentenceStart)
        $hasSkillContext = [regex]::IsMatch($sentence, '(?i)\bskill\b')
        $hasRoutingAction = [regex]::IsMatch(
            $prefix,
            '(?i)\b(?:load|use|read|consult|follow|invoke|route|apply)\b')
        if (-not $hasRoutingAction) {
            $suffixStart = $match.Index + $match.Length
            $suffix = $Text.Substring($suffixStart, $sentenceEnd - $suffixStart)
            $hasRoutingAction = [regex]::IsMatch(
                $suffix,
                '(?i)^`?\s*(?:skill\s+)?(?:(?:should|must|may|can|could|would|will|is|needs?\s+to|has\s+to)\s+)?(?:be\s+)?(?:loaded|read|consulted|followed|invoked|routed|applied|used|required|necessary|needed|recommended)\b')
        }
        $lineNumber = 0
        foreach ($lineEntry in $LineMap) {
            if ($lineEntry.Start -le $match.Index) {
                $lineNumber = $lineEntry.Line
            }
        }

        [pscustomobject]@{
            Name = $match.Groups['name'].Value
            Line = $lineNumber
            Sentence = $sentence
            HasSkillContext = $hasSkillContext
            HasRoutingAction = $hasRoutingAction
        }
    }
}

function Get-CrowSkillMention {
    param([System.IO.FileInfo]$File)

    $paragraph = [System.Text.StringBuilder]::new()
    $lineMap = [System.Collections.Generic.List[object]]::new()
    foreach ($sourceLine in Get-CrowMarkdownContentLine -File $File) {
        if ([string]::IsNullOrWhiteSpace($sourceLine.Text)) {
            if ($paragraph.Length -gt 0) {
                Get-CrowSkillMentionFromParagraph -Text $paragraph.ToString() -LineMap $lineMap
                [void]$paragraph.Clear()
                $lineMap.Clear()
            }
            continue
        }

        if ($paragraph.Length -gt 0) {
            [void]$paragraph.Append(' ')
        }
        $lineMap.Add([pscustomobject]@{
            Start = $paragraph.Length
            Line = $sourceLine.Line
        })
        [void]$paragraph.Append($sourceLine.Text)
    }
    if ($paragraph.Length -gt 0) {
        Get-CrowSkillMentionFromParagraph -Text $paragraph.ToString() -LineMap $lineMap
    }
}

function Add-CrowAssetGraphEdge {
    param(
        [hashtable]$Graph,
        [string]$From,
        [string]$To,
        [string]$Kind,
        [string]$Reference = '',
        [string]$ReferenceLabel = '',
        [int]$Line = 0
    )

    $edge = [pscustomobject]@{
        From = $From
        To = $To
        Kind = $Kind
        Reference = $Reference
        ReferenceLabel = $ReferenceLabel
        Line = $Line
    }
    $Graph.Edges.Add($edge)
    if (-not $Graph.Outgoing.ContainsKey($From)) {
        $Graph.Outgoing[$From] = [System.Collections.Generic.List[object]]::new()
    }
    $Graph.Outgoing[$From].Add($edge)
}

function Test-CrowCollectionIncludesPath {
    param(
        [object[]]$Dependencies,
        [string]$RequiredPath
    )

    $pathComparison = Get-CrowPathComparison
    foreach ($dependency in $Dependencies) {
        if ($RequiredPath.Equals(
                $dependency.Path,
                $pathComparison)) {
            return $true
        }
        if ($dependency.IsDirectory -and
            $RequiredPath.StartsWith(
                "$($dependency.Path)/",
                $pathComparison)) {
            return $true
        }
    }

    return $false
}

function Get-CrowAssetDependencyReport {
    param([Parameter(Mandatory)][string]$RepoRoot)

    $root = (Resolve-Path -LiteralPath $RepoRoot).Path
    $agentsPath = Join-Path $root '.apm/agents'
    $skillsPath = Join-Path $root '.apm/skills'
    $collectionsPath = Join-Path $root 'collections'
    $pathComparison = Get-CrowPathComparison
    $pathComparer = Get-CrowPathStringComparer
    $graph = @{
        Nodes = [System.Collections.Generic.Dictionary[string, object]]::new($pathComparer)
        Edges = [System.Collections.Generic.List[object]]::new()
        Outgoing = [System.Collections.Generic.Dictionary[string, object]]::new($pathComparer)
        SkillNameToRoot = [System.Collections.Generic.Dictionary[string, string]]::new(
            [System.StringComparer]::OrdinalIgnoreCase)
    }
    $errors = [System.Collections.Generic.List[string]]::new()

    foreach ($skillFile in Get-ChildItem -LiteralPath $skillsPath -File -Filter 'SKILL.md' -Recurse) {
        $content = [System.IO.File]::ReadAllText($skillFile.FullName)
        $frontmatter = [regex]::Match(
            $content,
            '(?ms)^---\r?\n(?<body>.*?)\r?\n---')
        if (-not $frontmatter.Success) {
            continue
        }
        $nameMatch = [regex]::Match(
            $frontmatter.Groups['body'].Value,
            '(?m)^name:\s*(?<name>[^#\r\n]+)\s*$')
        if (-not $nameMatch.Success) {
            continue
        }

        $skillName = $nameMatch.Groups['name'].Value.Trim().Trim('"', "'")
        $skillRoot = Get-CrowRepositoryRelativePath `
            -Root $root `
            -Path $skillFile.Directory.FullName
        if ([string]::IsNullOrWhiteSpace($skillName) -or
            [string]::IsNullOrWhiteSpace($skillRoot)) {
            continue
        }
        if ($graph.SkillNameToRoot.ContainsKey($skillName)) {
            $errors.Add("Dependency graph found duplicate skill name '$skillName'.")
            continue
        }
        $graph.SkillNameToRoot[$skillName] = $skillRoot
        $graph.Nodes[$skillRoot] = [pscustomobject]@{
            Path = $skillRoot
            Kind = 'Skill'
        }
    }

    $assetMarkdownFiles = @(
        Get-ChildItem -LiteralPath $agentsPath, $skillsPath -File -Filter '*.md' -Recurse
        if (Test-Path -LiteralPath $collectionsPath -PathType Container) {
            Get-ChildItem -LiteralPath $collectionsPath -File -Filter '*.md' -Recurse
        }
        $readmePath = Join-Path $root 'README.md'
        if (Test-Path -LiteralPath $readmePath -PathType Leaf) {
            Get-Item -LiteralPath $readmePath
        }
    )

    foreach ($markdownFile in $assetMarkdownFiles) {
        $sourcePath = Get-CrowRepositoryRelativePath `
            -Root $root `
            -Path $markdownFile.FullName
        if ([string]::IsNullOrWhiteSpace($sourcePath)) {
            continue
        }

        $sourceSkillRoot = Get-CrowSkillRootForPath `
            -RelativePath $sourcePath `
            -SkillNameToRoot $graph.SkillNameToRoot
        $sourceKind = if ($sourcePath.StartsWith('.apm/agents/', $pathComparison)) {
            'Agent'
        }
        elseif ($null -ne $sourceSkillRoot) {
            'SkillFile'
        }
        else {
            'Document'
        }
        $graph.Nodes[$sourcePath] = [pscustomobject]@{
            Path = $sourcePath
            Kind = $sourceKind
            SkillRoot = $sourceSkillRoot
        }

        foreach ($link in Get-CrowMarkdownLink -File $markdownFile) {
            try {
                $linkTarget = $link.Target
                if ($linkTarget.StartsWith('/') -and -not $linkTarget.StartsWith('//')) {
                    $targetFullPath = [System.IO.Path]::GetFullPath(
                        (Join-Path $root $linkTarget.TrimStart('/')))
                }
                else {
                    $targetFullPath = [System.IO.Path]::GetFullPath(
                        (Join-Path $markdownFile.Directory.FullName $linkTarget))
                }
            }
            catch {
                $errors.Add(
                    "Invalid local Markdown link in '$sourcePath' (line $($link.Line)): '$($link.Target)'.")
                continue
            }

            $targetPath = Get-CrowRepositoryRelativePath -Root $root -Path $targetFullPath
            if ([string]::IsNullOrWhiteSpace($targetPath)) {
                $errors.Add(
                    "Local Markdown link in '$sourcePath' (line $($link.Line)) escapes the repository: '$($link.Target)'.")
                continue
            }
            if (-not (Test-Path -LiteralPath $targetFullPath)) {
                $errors.Add(
                    "Dead local Markdown link in '$sourcePath' (line $($link.Line)): '$($link.Target)' does not exist.")
                continue
            }

            Add-CrowAssetGraphEdge `
                -Graph $graph `
                -From $sourcePath `
                -To $targetPath `
                -Kind 'MarkdownLink' `
                -Reference $link.Reference `
                -ReferenceLabel $link.ReferenceLabel `
                -Line $link.Line
        }

        if ($sourceKind -in @('Agent', 'SkillFile')) {
            foreach ($mention in Get-CrowSkillMention -File $markdownFile) {
                $skillName = $mention.Name
                if (-not $mention.HasSkillContext -or -not $mention.HasRoutingAction) {
                    continue
                }
                if (-not $graph.SkillNameToRoot.ContainsKey($skillName)) {
                    $errors.Add(
                        "Unknown skill reference '$skillName' in '$sourcePath' (line $($mention.Line)).")
                    continue
                }
                if ($sourceSkillRoot -eq $graph.SkillNameToRoot[$skillName]) {
                    continue
                }

                $skillRoot = $graph.SkillNameToRoot[$skillName]
                $hasExplicitModuleLink = $false
                if ($graph.Outgoing.ContainsKey($sourcePath)) {
                    $hasExplicitModuleLink = @($graph.Outgoing[$sourcePath] | Where-Object {
                        $isReferencedInSentence = $mention.Sentence.Contains($_.Reference)
                        if (-not $isReferencedInSentence -and $_.ReferenceLabel) {
                            $labelPattern = [regex]::Escape($_.ReferenceLabel).Replace('\ ', '\s+')
                            $referenceUsePatterns = @(
                                "\]\[$labelPattern\]",
                                "\[$labelPattern\]\[\s*\]",
                                "(?<!\!)\[$labelPattern\](?![\[(])"
                            )
                            foreach ($referenceUsePattern in $referenceUsePatterns) {
                                if ([regex]::IsMatch(
                                        $mention.Sentence,
                                        $referenceUsePattern,
                                        [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)) {
                                    $isReferencedInSentence = $true
                                    break
                                }
                            }
                        }
                        $_.Kind -eq 'MarkdownLink' -and
                        $isReferencedInSentence -and
                        $_.To.StartsWith(
                            "$skillRoot/modules/",
                            $pathComparison)
                    }).Count -gt 0
                }
                if ($hasExplicitModuleLink) {
                    continue
                }

                Add-CrowAssetGraphEdge `
                    -Graph $graph `
                    -From $sourcePath `
                    -To "$skillRoot/SKILL.md" `
                    -Kind 'SkillReference' `
                    -Line $mention.Line
            }
        }
    }

    foreach ($collectionDirectory in Get-ChildItem -LiteralPath $collectionsPath -Directory) {
        $manifestPath = Join-Path $collectionDirectory.FullName 'apm.yml'
        if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
            continue
        }

        $collectionId = "collections/$($collectionDirectory.Name)"
        $graph.Nodes[$collectionId] = [pscustomobject]@{
            Path = $collectionId
            Kind = 'Collection'
        }
        $manifest = [System.IO.File]::ReadAllText($manifestPath)
        $dependencyPaths = @(
            [regex]::Matches($manifest, '(?m)^\s{6}path:\s+([^\s#]+)\s*$') |
                ForEach-Object { $_.Groups[1].Value.Replace('\', '/').TrimEnd('/') }
        )
        $dependencies = [System.Collections.Generic.List[object]]::new()
        foreach ($dependencyPath in $dependencyPaths) {
            $dependencyFullPath = Join-Path $root $dependencyPath
            if (-not (Test-Path -LiteralPath $dependencyFullPath)) {
                continue
            }

            $dependency = [pscustomobject]@{
                Path = $dependencyPath
                FullPath = $dependencyFullPath
                IsDirectory = Test-Path -LiteralPath $dependencyFullPath -PathType Container
            }
            $dependencies.Add($dependency)
            Add-CrowAssetGraphEdge `
                -Graph $graph `
                -From $collectionId `
                -To $dependencyPath `
                -Kind 'Bundle'
        }

        $visited = [System.Collections.Generic.HashSet[string]]::new($pathComparer)
        $queue = [System.Collections.Queue]::new()
        foreach ($dependency in $dependencies) {
            if ($dependency.IsDirectory) {
                $sourceFiles = Get-ChildItem -LiteralPath $dependency.FullPath -File -Filter '*.md' -Recurse
            }
            elseif ([System.IO.Path]::GetExtension($dependency.FullPath) -eq '.md') {
                $sourceFiles = @(Get-Item -LiteralPath $dependency.FullPath)
            }
            else {
                $sourceFiles = @()
            }

            foreach ($sourceFile in $sourceFiles) {
                $sourcePath = Get-CrowRepositoryRelativePath -Root $root -Path $sourceFile.FullName
                if ($sourcePath -and
                    ($sourcePath.StartsWith('.apm/agents/', $pathComparison) -or
                        $sourcePath.StartsWith('.apm/skills/', $pathComparison))) {
                    $queue.Enqueue($sourcePath)
                }
            }
        }

        while ($queue.Count -gt 0) {
            $sourcePath = [string]$queue.Dequeue()
            if ($visited.Contains($sourcePath)) {
                continue
            }
            [void]$visited.Add($sourcePath)
            if (-not $graph.Outgoing.ContainsKey($sourcePath)) {
                continue
            }

            foreach ($edge in $graph.Outgoing[$sourcePath]) {
                $requiredPath = $null
                if ($edge.Kind -eq 'SkillReference') {
                    $requiredPath = $edge.To
                    $skillRoot = Get-CrowSkillRootForPath `
                        -RelativePath $requiredPath `
                        -SkillNameToRoot $graph.SkillNameToRoot
                    if ($skillRoot) {
                        $requiredPath = "$skillRoot/SKILL.md"
                    }
                }
                elseif ($edge.Kind -eq 'MarkdownLink' -and
                    $edge.To.StartsWith('.apm/skills/', $pathComparison)) {
                    $requiredPath = $edge.To
                }

                if (-not $requiredPath) {
                    continue
                }
                if (-not (Test-CrowCollectionIncludesPath `
                        -Dependencies @($dependencies) `
                        -RequiredPath $requiredPath)) {
                    $errors.Add(
                        "Collection '$($collectionDirectory.Name)' is missing required skill/module '$requiredPath' referenced by '$sourcePath'.")
                }

                $requiredFullPath = Join-Path $root $requiredPath
                if (Test-Path -LiteralPath $requiredFullPath -PathType Container) {
                    foreach ($targetFile in Get-ChildItem -LiteralPath $requiredFullPath -File -Filter '*.md' -Recurse) {
                        $targetRelativePath = Get-CrowRepositoryRelativePath -Root $root -Path $targetFile.FullName
                        if (-not $visited.Contains($targetRelativePath)) {
                            $queue.Enqueue($targetRelativePath)
                        }
                    }
                }
                elseif (Test-Path -LiteralPath $requiredFullPath -PathType Leaf) {
                    if (-not $visited.Contains($requiredPath)) {
                        $queue.Enqueue($requiredPath)
                    }
                }
            }
        }
    }

    return [pscustomobject]@{
        Graph = $graph
        Errors = @($errors | Select-Object -Unique)
    }
}
