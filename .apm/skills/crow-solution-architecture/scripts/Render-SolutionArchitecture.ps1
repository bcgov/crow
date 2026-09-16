[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$RepoRoot,

    [Parameter(Mandatory)]
    [string]$MarkdownPath,

    [Parameter(Mandatory)]
    [string]$OutputPath,

    [string]$JsonOutputPath,

    [switch]$Check
)

$ErrorActionPreference = 'Stop'
$root = (Resolve-Path -LiteralPath $RepoRoot).Path
$markdownFile = (Resolve-Path -LiteralPath $MarkdownPath).Path
$expectedMarkdownPath = [System.IO.Path]::GetFullPath(
    (Join-Path $root 'docs\solution-architecture.md'))
$expectedOutputPath = [System.IO.Path]::GetFullPath(
    (Join-Path $root 'docs\solution-architecture.html'))
$expectedJsonPath = [System.IO.Path]::GetFullPath(
    (Join-Path $root 'docs\solution-architecture-data.json'))
$comparison = if ([System.IO.Path]::DirectorySeparatorChar -eq '\') {
    [System.StringComparison]::OrdinalIgnoreCase
}
else {
    [System.StringComparison]::Ordinal
}

if (-not $markdownFile.Equals($expectedMarkdownPath, $comparison)) {
    throw "MarkdownPath must resolve to $expectedMarkdownPath."
}
if (-not [System.IO.Path]::GetFullPath($OutputPath).Equals($expectedOutputPath, $comparison)) {
    throw "OutputPath must resolve to $expectedOutputPath."
}
if (
    $JsonOutputPath -and
    -not [System.IO.Path]::GetFullPath($JsonOutputPath).Equals($expectedJsonPath, $comparison)
) {
    throw "JsonOutputPath must resolve to $expectedJsonPath."
}

$candidate = Split-Path -Parent $expectedOutputPath
while ($candidate.StartsWith($root, $comparison)) {
    if (Test-Path -LiteralPath $candidate) {
        $item = Get-Item -LiteralPath $candidate -Force
        if (($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
            throw "Solution architecture output traverses a symbolic link or junction: $($item.FullName)"
        }
    }
    if ($candidate -eq $root) {
        break
    }
    $candidate = Split-Path -Parent $candidate
}

$templatePath = Join-Path $PSScriptRoot '..\templates\solution-architecture-template.html'
$template = [System.IO.File]::ReadAllText((Resolve-Path -LiteralPath $templatePath).Path)
$markdown = [System.IO.File]::ReadAllText($markdownFile)
$markdownBytes = [System.IO.File]::ReadAllBytes($markdownFile)
$sourceHash = [System.BitConverter]::ToString(
    [System.Security.Cryptography.SHA256]::Create().ComputeHash($markdownBytes)
).Replace('-', '').ToLowerInvariant()
$utf8 = [System.Text.UTF8Encoding]::new($false)

function ConvertTo-HtmlText {
    param([AllowEmptyString()][string]$Value)
    return [System.Net.WebUtility]::HtmlEncode($Value)
}

function ConvertTo-Slug {
    param([string]$Value)
    $slug = $Value.ToLowerInvariant() -replace '[^a-z0-9]+', '-'
    return $slug.Trim('-')
}

function Convert-InlineMarkdown {
    param([AllowEmptyString()][string]$Value)
    $encoded = ConvertTo-HtmlText $Value
    $encoded = [regex]::Replace(
        $encoded,
        '`([^`]+)`',
        '<code>$1</code>')
    $encoded = [regex]::Replace(
        $encoded,
        '\[([^\]]+)\]\((https://[^)\s]+)\)',
        '<a href="$2" rel="noopener noreferrer">$1</a>')
    return $encoded
}

function Convert-MarkdownFragment {
    param([AllowEmptyString()][string]$Value)

    $lines = $Value -split "\r?\n"
    $builder = [System.Text.StringBuilder]::new()
    $paragraph = [System.Collections.Generic.List[string]]::new()
    $listType = $null
    $inCode = $false
    $codeLanguage = ''
    $codeLines = [System.Collections.Generic.List[string]]::new()

    function Flush-Paragraph {
        if ($paragraph.Count -gt 0) {
            [void]$builder.Append('<p>')
            [void]$builder.Append((Convert-InlineMarkdown ($paragraph -join ' ')))
            [void]$builder.AppendLine('</p>')
            $paragraph.Clear()
        }
    }

    function Close-List {
        if ($listType) {
            [void]$builder.AppendLine("</$listType>")
            Set-Variable -Name listType -Scope 1 -Value $null
        }
    }

    $index = 0
    while ($index -lt $lines.Count) {
        $line = $lines[$index]

        if ($line -match '^```(.*)$') {
            Flush-Paragraph
            Close-List
            if (-not $inCode) {
                $inCode = $true
                $codeLanguage = $Matches[1].Trim()
                $codeLines.Clear()
            }
            else {
                if ($codeLanguage -eq 'mermaid') {
                    $flowItems = [System.Collections.Generic.List[string]]::new()
                    foreach ($flowLine in $codeLines) {
                        $normalizedFlow = $flowLine -replace '-->>|->>|-\.->|==>|-->|->', '-->'
                        if ($normalizedFlow -notmatch '-->') {
                            continue
                        }
                        $parts = $normalizedFlow -split '-->', 2
                        $fromToken = $parts[0].Trim()
                        $toToken = $parts[1].Trim()
                        $interaction = ''
                        if ($toToken -match '^\|([^|]+)\|\s*(.+)$') {
                            $interaction = $Matches[1].Trim()
                            $toToken = $Matches[2].Trim()
                        }
                        elseif ($toToken -match '^([^:]+):\s*(.+)$') {
                            $toToken = $Matches[1].Trim()
                            $interaction = $Matches[2].Trim()
                        }

                        $from = if ($fromToken -match '^[A-Za-z0-9_-]+\s*[\[\(\{]+(.+?)[\]\)\}]+\s*$') {
                            $Matches[1].Trim()
                        }
                        else {
                            $fromToken
                        }
                        $to = if ($toToken -match '^[A-Za-z0-9_-]+\s*[\[\(\{]+(.+?)[\]\)\}]+\s*$') {
                            $Matches[1].Trim()
                        }
                        else {
                            $toToken
                        }
                        $interactionHtml = if ($interaction) {
                            ' <span>' + (ConvertTo-HtmlText $interaction) + '</span>'
                        }
                        else {
                            ''
                        }
                        $flowItems.Add(
                            '<li><strong>' + (ConvertTo-HtmlText $from) +
                            '</strong>' + $interactionHtml + ' to <strong>' +
                            (ConvertTo-HtmlText $to) +
                            '</strong></li>')
                    }
                    if ($flowItems.Count -eq 0) {
                        throw 'A Mermaid diagram did not contain a supported flow arrow.'
                    }
                    [void]$builder.AppendLine('<figure class="flow-view">')
                    [void]$builder.AppendLine('<ol class="flow-list">')
                    foreach ($flowItem in $flowItems) {
                        [void]$builder.AppendLine($flowItem)
                    }
                    [void]$builder.AppendLine('</ol>')
                    [void]$builder.AppendLine('<figcaption>Architecture flow derived from the canonical Mermaid source.</figcaption>')
                    [void]$builder.AppendLine('</figure>')
                }
                $languageClass = ' class="language-' + (ConvertTo-HtmlText $codeLanguage) + '"'
                [void]$builder.AppendLine('<details><summary>Diagram or code source</summary>')
                [void]$builder.Append("<pre><code$languageClass>")
                [void]$builder.Append((ConvertTo-HtmlText ($codeLines -join "`n")))
                [void]$builder.AppendLine('</code></pre>')
                [void]$builder.AppendLine('</details>')
                $inCode = $false
            }
            $index++
            continue
        }

        if ($inCode) {
            $codeLines.Add($line)
            $index++
            continue
        }

        if (
            $line -match '^\s*\|' -and
            ($index + 1) -lt $lines.Count -and
            $lines[$index + 1] -match '^\s*\|(?:\s*:?-+:?\s*\|)+\s*$'
        ) {
            Flush-Paragraph
            Close-List
            $headers = @($line.Trim().Trim('|').Split('|') | ForEach-Object { $_.Trim() })
            $index += 2
            $rows = [System.Collections.Generic.List[object]]::new()
            while ($index -lt $lines.Count -and $lines[$index] -match '^\s*\|') {
                $rows.Add(@($lines[$index].Trim().Trim('|').Split('|') | ForEach-Object { $_.Trim() }))
                $index++
            }
            [void]$builder.AppendLine('<div class="table-wrap"><table><thead><tr>')
            foreach ($header in $headers) {
                [void]$builder.Append('<th scope="col">')
                [void]$builder.Append((Convert-InlineMarkdown $header))
                [void]$builder.AppendLine('</th>')
            }
            [void]$builder.AppendLine('</tr></thead><tbody>')
            foreach ($row in $rows) {
                [void]$builder.AppendLine('<tr>')
                foreach ($cell in $row) {
                    [void]$builder.Append('<td>')
                    [void]$builder.Append((Convert-InlineMarkdown $cell))
                    [void]$builder.AppendLine('</td>')
                }
                [void]$builder.AppendLine('</tr>')
            }
            [void]$builder.AppendLine('</tbody></table></div>')
            continue
        }

        if ($line -match '^###\s+(.+)$') {
            Flush-Paragraph
            Close-List
            [void]$builder.Append('<h3>')
            [void]$builder.Append((Convert-InlineMarkdown $Matches[1]))
            [void]$builder.AppendLine('</h3>')
        }
        elseif ($line -match '^\s*[-*]\s+(.+)$') {
            Flush-Paragraph
            if ($listType -ne 'ul') {
                Close-List
                $listType = 'ul'
                [void]$builder.AppendLine('<ul>')
            }
            [void]$builder.Append('<li>')
            [void]$builder.Append((Convert-InlineMarkdown $Matches[1]))
            [void]$builder.AppendLine('</li>')
        }
        elseif ($line -match '^\s*\d+\.\s+(.+)$') {
            Flush-Paragraph
            if ($listType -ne 'ol') {
                Close-List
                $listType = 'ol'
                [void]$builder.AppendLine('<ol class="flow-list">')
            }
            [void]$builder.Append('<li>')
            [void]$builder.Append((Convert-InlineMarkdown $Matches[1]))
            [void]$builder.AppendLine('</li>')
        }
        elseif ([string]::IsNullOrWhiteSpace($line)) {
            Flush-Paragraph
            Close-List
        }
        elseif ($line -notmatch '^<!--' -and $line -notmatch '-->$') {
            $paragraph.Add($line.Trim())
        }

        $index++
    }

    if ($inCode) {
        throw 'Canonical Markdown contains an unclosed code fence.'
    }
    Flush-Paragraph
    Close-List
    return $builder.ToString()
}

if ($markdown -notmatch '(?m)^#\s+(.+)$') {
    throw 'Canonical Markdown is missing its level-one title.'
}
$documentTitle = $Matches[1].Trim()

$metadata = [System.Collections.Generic.List[string]]::new()
foreach ($label in @('Status', 'Owner', 'Last reviewed')) {
    if ($markdown -match ('(?m)^>\s*' + [regex]::Escape($label) + ':\s*`?([^`\r\n]+)`?\s*$')) {
        $metadata.Add(
            '<span><strong>' +
            (ConvertTo-HtmlText $label) +
            ':</strong> ' +
            (ConvertTo-HtmlText $Matches[1].Trim()) +
            '</span>')
    }
}

$matches = [regex]::Matches(
    $markdown,
    '(?ms)^##\s+(\d+\.\s+[^\r\n]+)\r?\n(.*?)(?=^##\s+\d+\.|\z)')
if ($matches.Count -eq 0) {
    throw 'Canonical Markdown does not contain numbered solution architecture sections.'
}

$navigation = [System.Text.StringBuilder]::new()
$sectionsHtml = [System.Text.StringBuilder]::new()
$jsonSections = [System.Collections.Generic.List[object]]::new()
foreach ($match in $matches) {
    $heading = $match.Groups[1].Value.Trim()
    $body = $match.Groups[2].Value.Trim()
    $id = ConvertTo-Slug $heading
    [void]$navigation.Append(
        '<a href="#' + (ConvertTo-HtmlText $id) + '">' +
        (ConvertTo-HtmlText $heading) + '</a>')

    $class = if ($heading -like '1.*') { ' class="summary"' } else { '' }
    [void]$sectionsHtml.AppendLine("<section id=`"$(ConvertTo-HtmlText $id)`"$class>")
    [void]$sectionsHtml.Append('<h2>')
    [void]$sectionsHtml.Append((ConvertTo-HtmlText $heading))
    [void]$sectionsHtml.AppendLine('</h2>')
    [void]$sectionsHtml.Append((Convert-MarkdownFragment $body))
    [void]$sectionsHtml.AppendLine('</section>')

    $jsonSections.Add([pscustomobject]@{
        id = $id
        heading = $heading
        markdown = $body
    })
}

$html = $template
$html = $html.Replace('{{MARKDOWN_SHA256}}', $sourceHash)
$html = $html.Replace('{{DOCUMENT_TITLE}}', (ConvertTo-HtmlText $documentTitle))
$html = $html.Replace('{{DOCUMENT_METADATA}}', ($metadata -join ''))
$html = $html.Replace('{{DOCUMENT_NAVIGATION}}', $navigation.ToString())
$html = $html.Replace('{{DOCUMENT_SECTIONS}}', $sectionsHtml.ToString())
$html = $html -replace "\r\n?", "`n"

$outputDirectory = Split-Path -Parent $expectedOutputPath
if (-not (Test-Path -LiteralPath $outputDirectory)) {
    if ($Check) {
        throw "Expected output directory is missing: $outputDirectory"
    }
    New-Item -ItemType Directory -Path $outputDirectory | Out-Null
}

$json = $null
if ($JsonOutputPath) {
    $json = [ordered]@{
        sourceSha256 = $sourceHash
        title = $documentTitle
        sections = $jsonSections
    } | ConvertTo-Json -Depth 5
    $json = $json -replace "\r\n?", "`n"
}

if ($Check) {
    if (-not (Test-Path -LiteralPath $expectedOutputPath -PathType Leaf)) {
        throw "Expected rendered HTML is missing: $expectedOutputPath"
    }
    if ([System.IO.File]::ReadAllText($expectedOutputPath) -cne $html) {
        throw 'Solution architecture HTML does not match the deterministic rendering.'
    }
    if ($JsonOutputPath) {
        if (-not (Test-Path -LiteralPath $expectedJsonPath -PathType Leaf)) {
            throw "Expected rendered JSON is missing: $expectedJsonPath"
        }
        if ([System.IO.File]::ReadAllText($expectedJsonPath) -cne $json) {
            throw 'Solution architecture JSON does not match the deterministic rendering.'
        }
    }
    return
}

[System.IO.File]::WriteAllText(
    $expectedOutputPath,
    $html,
    $utf8)

if ($JsonOutputPath) {
    [System.IO.File]::WriteAllText(
        $expectedJsonPath,
        $json,
        $utf8)
}
