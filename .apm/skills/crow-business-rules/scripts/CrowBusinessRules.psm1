<#
.SYNOPSIS
  Shared contract, validation, escaping, and sanitization helpers for Crow
  business-rule documentation.

.DESCRIPTION
  This module is the authoritative validation source for
  business-rules-data.json. business-rules-data.schema.json documents the same
  contract for editors; Test-CrowBusinessRules.Tests.ps1 fails when the two
  drift.

  The module is imported by render-business-rules.ps1 and
  Test-BusinessRuleData.ps1. It performs no file writes on import and never
  executes data content.
#>

$script:CrowBusinessRuleContract = @{
    SchemaVersion          = '1.0'
    RuleIdPattern          = '^BR-[0-9]{4,6}$'
    SourceIdPattern        = '^DOC-[0-9]{1,4}$'
    GroupIdPattern         = '^[a-z][a-z0-9-]{1,39}$'
    FacetIdPattern         = '^[a-z][a-z0-9-]{1,39}\.[a-z0-9][a-z0-9-]{0,39}$'
    DiagramIdPattern       = '^[a-z][a-z0-9-]{1,39}$'
    CommitPattern          = '^[0-9a-f]{7,40}$'
    DatePattern            = '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
    CitationPathPattern    = '^[A-Za-z0-9._-][A-Za-z0-9 ._/-]*$'
    RootRequired           = @(
        'schema_version', 'application', 'generated', 'documentation_sources',
        'documentation_gap', 'facet_groups', 'rules', 'diagrams')
    RootOptional           = @('open_questions')
    ApplicationRequired    = @('name', 'scope', 'repository', 'commit')
    ApplicationOptional    = @('acronym', 'scope_note')
    SourceRequired         = @('id', 'title', 'kind', 'status', 'location')
    SourceOptional         = @('note')
    GapRequired            = @('present')
    GapOptional            = @('summary', 'coverage_impact')
    GroupRequired          = @('id', 'label', 'facets')
    GroupOptional          = @('description')
    FacetRequired          = @('id', 'label')
    FacetOptional          = @('description')
    RuleRequired           = @(
        'id', 'title', 'status', 'category', 'statement', 'facets',
        'citations', 'documentation_refs', 'reconciliation')
    RuleOptional           = @('rationale', 'match_notes', 'retirement')
    CitationRequired       = @('path', 'symbol', 'commit')
    CitationOptional       = @('line')
    ReconciliationRequired = @('classification')
    ReconciliationOptional = @('note')
    RetirementRequired     = @('retired_on', 'reason')
    RetirementOptional     = @()
    MatchNoteRequired      = @('facet', 'reason')
    MatchNoteOptional      = @()
    DiagramRequired        = @('id', 'title', 'description', 'mermaid', 'rule_refs')
    DiagramOptional        = @()
    Categories             = @(
        'authorization', 'validation', 'workflow', 'calculation', 'temporal',
        'location', 'environment', 'configuration', 'feature-flag',
        'persistence', 'integration', 'error-handling', 'degradation',
        'test-derived')
    Classifications        = @(
        'aligned', 'implemented-only', 'documented-only', 'conflicting',
        'unverifiable')
    RuleStatuses           = @('active', 'retired')
    SourceStatuses         = @('available', 'unavailable')
    SourceKinds            = @(
        'guide', 'training', 'policy', 'specification', 'ticket', 'other')
}

# Rendered-SVG security tables. They are matched against parsed element names,
# attribute names, and URL schemes, never against visible text.
$script:CrowSvgForbiddenElements = @{
    'script'           = 'contains a script element'
    'foreignobject'    = 'contains a foreignObject element'
    'image'            = 'contains an image element'
    'iframe'           = 'contains an embedded or animated element'
    'object'           = 'contains an embedded or animated element'
    'embed'            = 'contains an embedded or animated element'
    'applet'           = 'contains an embedded or animated element'
    'link'             = 'contains an embedded or animated element'
    'audio'            = 'contains an embedded or animated element'
    'video'            = 'contains an embedded or animated element'
    'feimage'          = 'contains an embedded or animated element'
    'animate'          = 'contains an embedded or animated element'
    'animatetransform' = 'contains an embedded or animated element'
    'animatemotion'    = 'contains an embedded or animated element'
    'animatecolor'     = 'contains an embedded or animated element'
    'discard'          = 'contains an embedded or animated element'
    'handler'          = 'contains an embedded or animated element'
    'listener'         = 'contains an embedded or animated element'
    'set'              = 'contains an embedded or animated element'
}

# Attributes whose value is fetched or navigated to. 'use' is not forbidden as
# an element: its href is checked here and must be same-document.
$script:CrowSvgUrlAttributes = @(
    'href', 'xlink:href', 'src', 'xlink:src', 'data', 'action', 'formaction',
    'poster', 'background', 'ping', 'srcset', 'xlink:role', 'xlink:arcrole')

$script:CrowUnsafeUrlSchemes = @(
    'javascript', 'vbscript', 'livescript', 'mocha', 'data', 'blob',
    'filesystem', 'file', 'about', 'jar', 'view-source')

# Mermaid UML annotations and stereotypes, for example '<<interface>>',
# '<<abstract>>', '<<enumeration>>', '<<fork>>', '<<join>>', and '<<choice>>'.
# The grammar admits a leading letter followed by letters, digits, spaces,
# underscores, and hyphens only, so it cannot express a tag name with
# attributes, a solidus, an equals sign, a colon, or a quote.
$script:CrowMermaidAnnotationPattern = '<<[A-Za-z][A-Za-z0-9 _-]{0,38}>>'

function Get-CrowBusinessRuleContract {
    <#
    .SYNOPSIS
      Returns the authoritative business-rule data contract.
    #>
    [CmdletBinding()]
    param()

    return $script:CrowBusinessRuleContract
}

function Get-CrowProperty {
    [CmdletBinding()]
    param(
        [AllowNull()][object]$Object,
        [Parameter(Mandatory)][string]$Name
    )

    if ($null -eq $Object) { return $null }
    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property) { return $null }
    return $property.Value
}

function Get-CrowArray {
    <#
    .SYNOPSIS
      Returns a JSON array member as an array, treating a missing member as
      empty instead of a single null element.
    #>
    [CmdletBinding()]
    param([AllowNull()][object]$Value)

    if ($null -eq $Value) { return @() }
    return @($Value)
}
function Test-CrowObjectShape {
    [CmdletBinding()]
    param(
        [AllowNull()][object]$Object,
        [Parameter(Mandatory)][string]$Path,
        [string[]]$Required = @(),
        [string[]]$Optional = @(),
        [Parameter(Mandatory)][object]$Errors
    )

    if ($null -eq $Object -or -not ($Object -is [System.Management.Automation.PSCustomObject])) {
        $Errors.Add("$Path must be a JSON object.")
        return $false
    }

    $names = @($Object.PSObject.Properties | ForEach-Object { $_.Name })
    foreach ($name in $Required) {
        if ($names -notcontains $name) {
            $Errors.Add("$Path is missing required property '$name'.")
        }
    }
    $allowed = @($Required + $Optional)
    foreach ($name in $names) {
        if ($allowed -notcontains $name) {
            $Errors.Add("$Path contains unsupported property '$name'.")
        }
    }
    return $true
}

function Test-CrowText {
    [CmdletBinding()]
    param(
        [AllowNull()][object]$Value,
        [Parameter(Mandatory)][string]$Path,
        [string]$Pattern,
        [string[]]$AllowedValues,
        [switch]$Optional,
        [Parameter(Mandatory)][object]$Errors
    )

    if ($null -eq $Value) {
        if (-not $Optional) { $Errors.Add("$Path is required.") }
        return
    }
    if (-not ($Value -is [string])) {
        $Errors.Add("$Path must be a string.")
        return
    }
    if ([string]::IsNullOrWhiteSpace($Value)) {
        $Errors.Add("$Path must not be empty.")
        return
    }
    if ($Pattern -and ($Value -cnotmatch $Pattern)) {
        $Errors.Add("$Path value '$Value' does not match $Pattern.")
    }
    if ($AllowedValues -and ($AllowedValues -notcontains $Value)) {
        $Errors.Add("$Path value '$Value' must be one of: $($AllowedValues -join ', ').")
    }
}

function Get-CrowDataString {
    <#
    .SYNOPSIS
      Enumerates every string value in the parsed data with its JSON path.
    #>
    [CmdletBinding()]
    param(
        [AllowNull()][object]$Node,
        [Parameter(Mandatory)][string]$Path
    )

    if ($null -eq $Node) { return }
    if ($Node -is [string]) {
        [pscustomobject]@{ Path = $Path; Value = $Node }
        return
    }
    if ($Node -is [System.Management.Automation.PSCustomObject]) {
        foreach ($property in $Node.PSObject.Properties) {
            Get-CrowDataString -Node $property.Value -Path "$Path.$($property.Name)"
        }
        return
    }
    if ($Node -is [System.Collections.IEnumerable]) {
        $index = 0
        foreach ($item in $Node) {
            Get-CrowDataString -Node $item -Path "$Path[$index]"
            $index++
        }
    }
}

function Test-CrowMermaidSource {
    <#
    .SYNOPSIS
      Rejects Mermaid source constructs that can execute script, load remote
      content, or bypass the strict renderer configuration.

    .DESCRIPTION
      The patterns are scoped to Mermaid directives, interaction bindings, and
      URL syntax rather than to bare words, so ordinary label text such as
      'Call centre', 'Data: pending', or 'Script review' is accepted while
      init directives, 'click' statements, 'href'/'call' bindings, absolute and
      javascript:/data: URLs, style imports, and raw HTML are still rejected.
      'click' is treated as a directive at any statement position (line start or
      after ';'), so it cannot be hidden after a separator inside a label, and
      'href', 'call', and 'callback' are rejected whenever they are followed by
      binding syntax ('(', '=', ':', or a quote).

      A line that starts a Markdown code fence is also rejected. The Markdown
      report embeds the diagram source in a ```mermaid block, so a line-initial
      run of three or more backticks (optionally indented by up to three spaces,
      as CommonMark allows) would close that block and let the rest of the source
      be interpreted as document markup. The renderer fails closed on that input
      instead of choosing a longer fence at run time, so the published fence
      stays a fixed, reviewable part of the template contract.

      Mermaid's own UML annotations and stereotypes are written with guillemet
      pairs: '<<interface>>', '<<abstract>>' and '<<enumeration>>' in class
      diagrams, and '<<fork>>', '<<join>>' and '<<choice>>' in state diagrams.
      They are Mermaid syntax, not markup, so they are removed from the copy the
      raw-HTML rule reads. The accepted grammar is deliberately narrow: a
      leading letter followed by letters, digits, spaces, underscores, and
      hyphens only. It admits no '<', '>', '/', '=', ':', or quote character, so
      it cannot express a tag, an attribute, a URL, or a scheme, and every other
      rule still reads the original source. '<<script>>' is therefore still
      rejected, and so is any real raw HTML such as '<b>' or '<img src=x>'.
    #>
    [CmdletBinding()]
    param(
        [AllowNull()][object]$Source,
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][object]$Errors
    )

    if (-not ($Source -is [string]) -or [string]::IsNullOrWhiteSpace($Source)) {
        $Errors.Add("$Path must be a non-empty Mermaid diagram definition.")
        return
    }

    # Mermaid UML annotations are syntax rather than markup, so the raw-HTML
    # rule reads a copy with the valid ones removed. Every other rule reads the
    # original source.
    $withoutAnnotations = [regex]::Replace(
        $Source, $script:CrowMermaidAnnotationPattern, ' ')

    $forbidden = @(
        @{ Pattern = '%%\{'; Reason = 'Mermaid init directives are not allowed' },
        @{ Pattern = '(?im)(?:^|;)\s*click\b'; Reason = 'click interactions are not allowed' },
        @{ Pattern = '(?i)\b(?:href|call|callback)\s*(?:\(|=|:|"|'')'; Reason = 'href and call bindings are not allowed' },
        @{ Pattern = '(?m)^[ \t]{0,3}```'; Reason = 'Markdown code fences are not allowed in diagram source' },
        @{ Pattern = '(?i)<\s*/?\s*script\b'; Reason = 'script elements are not allowed' },
        @{ Pattern = '(?i)\bjavascript:'; Reason = 'javascript: URLs are not allowed' },
        @{ Pattern = '(?i)\bdata:[^\s,]*,'; Reason = 'data: URLs are not allowed' },
        @{ Pattern = '(?i)\b[a-z][a-z0-9+.-]*://'; Reason = 'absolute URLs are not allowed' },
        @{ Pattern = '(?i)@import'; Reason = 'CSS imports are not allowed' }
    )
    foreach ($rule in $forbidden) {
        if ($Source -match $rule.Pattern) {
            $Errors.Add("$Path is rejected: $($rule.Reason).")
        }
    }
    if ($withoutAnnotations -match '<\s*[A-Za-z!/]') {
        $Errors.Add("$Path is rejected: raw HTML is not allowed. Mermaid UML annotations such as " +
            "'<<interface>>' or '<<fork>>' are allowed, and may contain only letters, digits, " +
            'spaces, underscores, and hyphens.')
    }
}

function New-CrowMarkupToken {
    <#
    .SYNOPSIS
      Creates one classified markup token for Get-CrowMarkupToken.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][ValidateSet(
            'text', 'element', 'comment', 'cdata', 'declaration', 'instruction', 'malformed')]
        [string]$Kind,
        [Parameter(Mandatory)][AllowEmptyString()][string]$Text,
        [string]$Name = '',
        [switch]$IsClosing,
        [switch]$IsSelfClosing
    )

    return [pscustomobject]@{
        Kind          = $Kind
        Text          = $Text
        Name          = $Name
        IsClosing     = [bool]$IsClosing
        IsSelfClosing = [bool]$IsSelfClosing
    }
}

function Get-CrowMarkupTagEnd {
    <#
    .SYNOPSIS
      Scans one start or end tag from the first character after its tag name to
      the '>' that ends it, and reports whether a solidus self-closed it.

    .DESCRIPTION
      Attribute scanning is an explicit state machine with three value states:
      no value, a quoted value, and an unquoted value. An '=' only introduces a
      value directly after an attribute name; a stray '=' before a name, or one
      that follows a value that was already read, is an ordinary name character,
      exactly as HTML treats it. A quote only opens a quoted value when it is
      the first non-whitespace character after that '='. Once an unquoted value
      has begun, an internal '=' or quote is ordinary text: it can neither
      re-arm the "expecting a value" state nor open quoted mode, so
      'data-x=a="><script>' cannot swallow the elements that follow it. An
      unquoted value ends only at whitespace or at '>', exactly as HTML defines
      it, and the '>' therefore still ends the tag.

      The self-closing flag is taken from the scanner state rather than from the
      raw text, so a '/' that belongs to an unquoted attribute value, or that is
      separated from '>' by whitespace, does not mark the tag self-closing. A
      '/' outside a value never begins an attribute name either, so the '=' in
      '<svg /="><script>' cannot introduce a value.

      Scanning must begin after the tag name, never inside it, so the name's own
      letters cannot arm the "an '=' may follow a name" state. '<svg ="><script>'
      and '<svg="><script>' therefore end at the first '>', exactly as HTML ends
      them, and the script element that follows is tokenized as an element.

      Closed is $false when the text ends before a '>' is reached; the caller
      must treat that unterminated tag as malformed rather than as a tag.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][AllowEmptyString()][string]$Text,
        [Parameter(Mandatory)][int]$Start
    )

    $cursor = $Start
    $quote = [char]0
    $expectValue = $false
    $inUnquotedValue = $false
    $hasAttributeName = $false
    $solidusBeforeClose = $false
    $closed = $false
    while ($cursor -lt $Text.Length) {
        $character = $Text[$cursor]
        if ($quote -ne [char]0) {
            if ($character -eq $quote) {
                $quote = [char]0
                $hasAttributeName = $false
            }
            $solidusBeforeClose = $false
        }
        elseif ($inUnquotedValue) {
            if ($character -eq '>') { $closed = $true; break }
            if ([char]::IsWhiteSpace($character)) {
                $inUnquotedValue = $false
                $hasAttributeName = $false
            }
            $solidusBeforeClose = $false
        }
        elseif ($character -eq '>') { $closed = $true; break }
        elseif ($character -eq '=' -and $hasAttributeName) {
            $expectValue = $true
            $hasAttributeName = $false
            $solidusBeforeClose = $false
        }
        elseif ([char]::IsWhiteSpace($character)) {
            # Whitespace separates but does not end the attribute, so an '='
            # may still follow a name across it.
            $solidusBeforeClose = $false
        }
        elseif ($expectValue) {
            # The first non-whitespace character after '=' decides whether
            # the value is quoted or unquoted, so a '/' here begins an
            # unquoted value such as 'href=/path' rather than self-closing.
            $expectValue = $false
            if ($character -eq '"' -or $character -eq "'") { $quote = $character }
            else { $inUnquotedValue = $true }
            $solidusBeforeClose = $false
        }
        elseif ($character -eq '/') {
            # A solidus outside a value never begins or continues an
            # attribute name, so a following '=' cannot introduce a value.
            # It only self-closes the tag when '>' comes immediately next.
            $hasAttributeName = $false
            $solidusBeforeClose = $true
        }
        else {
            # An attribute-name character.
            $hasAttributeName = $true
            $solidusBeforeClose = $false
        }
        $cursor++
    }

    return [pscustomobject]@{
        Closed        = $closed
        End           = $cursor
        IsSelfClosing = $solidusBeforeClose
    }
}

function Get-CrowRawTextEndTag {
    <#
    .SYNOPSIS
      Finds the end tag that closes a 'script' or 'style' raw-text element.

    .DESCRIPTION
      HTML ends a raw-text end-tag name at whitespace, at '/', or at '>', and
      then reads on to the '>' that ends the tag, ignoring whatever sits between.
      '</style/>' and '</style foo>' therefore close the element exactly as
      '</style>' does, and a scanner that only accepted '</style>' would read the
      live markup after them as inert raw text. Any other character continues a
      different tag name, so the 's' of '</styles>' does not close 'style'.

      Whitespace directly after '</' is not allowed: browsers read '</ style>' as
      a bogus comment rather than as an end tag, so it leaves raw text open.

      Index is the position of the matching end tag, or -1 when the raw text has
      none. Closed reports whether the shared tag scanner could consume that end
      tag through its '>'; an end tag that is never closed is reported with
      Closed = $false so the caller rejects it instead of reading on to a later
      end tag.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][AllowEmptyString()][string]$Markup,
        [Parameter(Mandatory)][int]$Start,
        [Parameter(Mandatory)][string]$LocalName
    )

    $pattern = [regex]::new('(?i)</(?:[A-Za-z_][\w.-]*:)?' + [regex]::Escape($LocalName))
    $searchFrom = $Start
    while ($searchFrom -le $Markup.Length) {
        $match = $pattern.Match($Markup, $searchFrom)
        if (-not $match.Success) {
            return [pscustomobject]@{ Index = -1; Closed = $false }
        }
        $after = $match.Index + $match.Length
        if ($after -ge $Markup.Length) {
            # The name is never terminated, so the tag is unterminated too.
            return [pscustomobject]@{ Index = $match.Index; Closed = $false }
        }
        $character = $Markup[$after]
        if ([char]::IsWhiteSpace($character) -or $character -eq '/' -or $character -eq '>') {
            $scan = Get-CrowMarkupTagEnd -Text $Markup -Start $after
            return [pscustomobject]@{ Index = $match.Index; Closed = $scan.Closed }
        }
        # The name continues into a different tag name, so raw text goes on.
        $searchFrom = $match.Index + 2
    }
    return [pscustomobject]@{ Index = -1; Closed = $false }
}

function Get-CrowMarkupToken {
    <#
    .SYNOPSIS
      Splits markup into ordered tag, comment, declaration, instruction, CDATA,
      and text tokens so security checks can be applied to markup contexts only.

    .DESCRIPTION
      Every start and end tag is consumed by the shared Get-CrowMarkupTagEnd
      scanner, so quoted and unquoted attribute values, the self-closing flag,
      and unterminated tags are handled identically wherever a tag appears.

      Comments end at '-->', at the legacy '--!>' that browsers also accept, and
      immediately for the abrupt '<!-->' and '<!--->' forms. A comment body that
      contains a bare '--' without one of those terminators is illegal markup and
      is reported as malformed rather than skipped, so a comment cannot be used
      to smuggle an element past the checks.

      'script' and 'style' hold raw text rather than markup, so their content is
      consumed to the matching end tag and returned as a single 'text' token.
      That keeps '<' and '>' inside a script body from being read as elements.
      A trailing solidus does not change that: HTML has no self-closing 'script'
      or 'style', so '<style/>' opens a raw-text element and the tokens report
      IsSelfClosing as false. The end tag is matched the way HTML matches it, so
      the browser-valid '</style/>' and '</style foo>' forms close the element
      and the markup after them is tokenized as live markup rather than swallowed
      as raw text. Rendered SVG is inlined into the report and is parsed by the
      same HTML parser, so the rule is applied everywhere; a '<style/>' or
      '<script/>' with no matching end tag is malformed, which is a rejection
      rather than a pass.

      Any construct the scanner cannot classify, including an unterminated tag,
      comment, raw-text element, or quoted value, is returned as a 'malformed'
      token. Callers must treat that as a rejection: the scanner never repairs,
      strips, or removes content.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][AllowEmptyString()][string]$Markup)

    $ordinal = [System.StringComparison]::Ordinal
    $tokens = New-Object 'System.Collections.Generic.List[object]'
    $length = $Markup.Length
    $index = 0

    while ($index -lt $length) {
        $start = $Markup.IndexOf('<', $index)
        if ($start -lt 0) {
            $tokens.Add((New-CrowMarkupToken -Kind 'text' -Text $Markup.Substring($index)))
            break
        }
        if ($start -gt $index) {
            $tokens.Add((New-CrowMarkupToken -Kind 'text' -Text $Markup.Substring($index, $start - $index)))
        }
        $rest = $Markup.Substring($start)

        if ($rest.StartsWith('<!--', $ordinal)) {
            # An empty comment closes abruptly at '<!-->' or '<!--->'; browsers
            # end it there, so the scanner must not read on to a later '-->'.
            # Otherwise the body ends at the first '--', which only closes a
            # comment as '-->' or as the legacy '--!>'. Anything else is
            # malformed, never skipped.
            $raw = $null
            if ($rest.StartsWith('<!-->', $ordinal)) { $raw = '<!-->' }
            elseif ($rest.StartsWith('<!--->', $ordinal)) { $raw = '<!--->' }
            if ($null -eq $raw) {
                $bodyEnd = $rest.IndexOf('--', 4, $ordinal)
                $closeLength = 0
                if ($bodyEnd -ge 0) {
                    if (($bodyEnd + 3) -le $rest.Length -and $rest.Substring($bodyEnd, 3) -eq '-->') {
                        $closeLength = 3
                    }
                    elseif (($bodyEnd + 4) -le $rest.Length -and $rest.Substring($bodyEnd, 4) -eq '--!>') {
                        $closeLength = 4
                    }
                }
                if ($closeLength -eq 0) {
                    $tokens.Add((New-CrowMarkupToken -Kind 'malformed' -Text $rest))
                    break
                }
                $raw = $rest.Substring(0, $bodyEnd + $closeLength)
            }
            $tokens.Add((New-CrowMarkupToken -Kind 'comment' -Text $raw))
            $index = $start + $raw.Length
            continue
        }

        # CDATA sections, declarations, and processing instructions each end with
        # their own delimiter rather than at the first '>'.
        $delimited = $null
        if ($rest.StartsWith('<![CDATA[', $ordinal)) { $delimited = @{ Kind = 'cdata'; Close = ']]>' } }
        elseif ($rest.StartsWith('<!', $ordinal)) { $delimited = @{ Kind = 'declaration'; Close = '>' } }
        elseif ($rest.StartsWith('<?', $ordinal)) { $delimited = @{ Kind = 'instruction'; Close = '?>' } }
        if ($delimited) {
            $end = $rest.IndexOf($delimited.Close, 2, $ordinal)
            if ($end -lt 0) {
                $tokens.Add((New-CrowMarkupToken -Kind 'malformed' -Text $rest))
                break
            }
            $raw = $rest.Substring(0, $end + $delimited.Close.Length)
            $name = [regex]::Match($raw, '^<[!?]\s*(?<name>[A-Za-z_][\w.:-]*)').Groups['name'].Value
            $tokens.Add((New-CrowMarkupToken -Kind $delimited.Kind -Text $raw -Name $name))
            $index = $start + $raw.Length
            continue
        }

        # A tag name must follow '<' or '</' immediately. Browsers read '</ x'
        # as a bogus comment that ends at the first '>', ignoring quotes, so
        # accepting it as an end tag would let a quoted attribute value swallow
        # the live markup that follows. Anything that is not a tag is malformed,
        # which the callers reject.
        $nameMatch = [regex]::Match($rest, '^<(?<closing>/?)(?<name>[A-Za-z_][\w.:-]*)')
        if (-not $nameMatch.Success) {
            $tokens.Add((New-CrowMarkupToken -Kind 'malformed' -Text $rest))
            break
        }

        # Attribute scanning is delegated to the shared tag scanner, which starts
        # after the tag name so the name's own letters cannot arm the "an '='
        # may follow" state, and which ends the tag only at a '>' outside a
        # value.
        $scan = Get-CrowMarkupTagEnd -Text $rest -Start $nameMatch.Length
        if (-not $scan.Closed) {
            $tokens.Add((New-CrowMarkupToken -Kind 'malformed' -Text $rest))
            break
        }

        $raw = $rest.Substring(0, $scan.End + 1)
        $isClosing = $nameMatch.Groups['closing'].Value -eq '/'
        $isSelfClosing = $scan.IsSelfClosing

        # script and style contain raw text, not markup. HTML has no
        # self-closing script or style element, so a trailing solidus neither
        # closes the element nor suppresses raw-text scanning. HTML also ignores
        # a solidus on an end tag, so '</style/>' closes the element and is not
        # reported as self-closing.
        $localName = (($nameMatch.Groups['name'].Value -split ':')[-1]).ToLowerInvariant()
        $isRawText = (-not $isClosing) -and ($localName -eq 'script' -or $localName -eq 'style')
        if ($isRawText -or $isClosing) { $isSelfClosing = $false }

        $tokens.Add((New-CrowMarkupToken -Kind 'element' -Text $raw `
                    -Name $nameMatch.Groups['name'].Value `
                    -IsClosing:$isClosing `
                    -IsSelfClosing:$isSelfClosing))
        $index = $start + $raw.Length

        if ($isRawText) {
            # The end tag is matched the way HTML matches it: '</', an optional
            # namespace prefix, the exact local name, and then a character that
            # terminates the name. The tag itself is consumed to its '>' by the
            # shared scanner, so an end tag that is never closed is malformed
            # instead of being skipped in favour of a later end tag.
            $close = Get-CrowRawTextEndTag -Markup $Markup -Start $index -LocalName $localName
            if ($close.Index -lt 0 -or -not $close.Closed) {
                $tokens.Add((New-CrowMarkupToken -Kind 'malformed' -Text $Markup.Substring($index)))
                break
            }
            if ($close.Index -gt $index) {
                $tokens.Add((New-CrowMarkupToken -Kind 'text' `
                            -Text $Markup.Substring($index, $close.Index - $index)))
            }
            $index = $close.Index
        }
    }

    return $tokens
}

function Get-CrowMarkupAttribute {
    <#
    .SYNOPSIS
      Returns the attribute names and values of a single start tag.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Tag)

    $body = [regex]::Replace($Tag, '^<\s*/?\s*[A-Za-z_][\w.:-]*', '')
    $body = [regex]::Replace($body, '/?\s*>$', '')
    $pattern = '(?<name>[A-Za-z_:][-\w.:]*)\s*(?:=\s*(?:"(?<value>[^"]*)"|' +
    "'(?<value>[^']*)'" + '|(?<value>[^\s"''=<>`]+)))?'
    foreach ($match in [regex]::Matches($body, $pattern)) {
        [pscustomobject]@{
            Name  = $match.Groups['name'].Value
            Value = $match.Groups['value'].Value
        }
    }
}

function Get-CrowUnsafeUrlScheme {
    <#
    .SYNOPSIS
      Returns the scheme of a URL value when that scheme can execute script or
      inline a foreign document, and $null otherwise.

    .DESCRIPTION
      The value is entity-decoded and stripped of the whitespace and control
      characters browsers ignore before the scheme is read, so 'java\nscript:'
      and 'javascript&#58;' are classified like 'javascript:'.
    #>
    [CmdletBinding()]
    param([AllowNull()][string]$Value)

    if ([string]::IsNullOrWhiteSpace($Value)) { return $null }
    $decoded = [System.Net.WebUtility]::HtmlDecode($Value)
    $normalized = [regex]::Replace($decoded, '[\x00-\x20\s]', '')
    $match = [regex]::Match($normalized, '^(?<scheme>[A-Za-z][A-Za-z0-9+.-]*):')
    if (-not $match.Success) { return $null }
    $scheme = $match.Groups['scheme'].Value.ToLowerInvariant()
    if ($script:CrowUnsafeUrlSchemes -contains $scheme) { return $scheme }
    return $null
}

function Test-CrowStyleValue {
    <#
    .SYNOPSIS
      Applies CSS-context checks to a <style> element body, a style attribute, or
      any attribute value that carries url() syntax.

    .DESCRIPTION
      Supply -RawText for the content of a style element. CSS has no use for '<',
      and neither Mermaid's generated stylesheets nor the bundled report
      stylesheet contain one, so a '<' inside style content means the tokenizer
      and the browser disagree about where the raw text ends. That is rejected as
      a defense-in-depth invariant rather than parsed further. The switch is not
      used for attribute values, where '<' is ordinary escaped text.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][AllowEmptyString()][string]$Text,
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][object]$Errors,
        [switch]$RawText
    )

    if ($RawText -and $Text.Contains('<')) {
        $Errors.Add("$Path contains a '<' character inside a style element, which valid CSS never " +
            'needs; the rendered diagram was rejected.')
    }
    if ($Text -match '(?i)@import') {
        $Errors.Add("$Path contains a CSS import; the rendered diagram was rejected.")
    }
    if ($Text -match '(?i)\b(?:javascript|vbscript|livescript)\s*:') {
        $Errors.Add("$Path contains a javascript: URL in a style context; the rendered diagram was rejected.")
    }
    if ($Text -match '(?i)\bdata:[^\s,;]*,') {
        $Errors.Add("$Path contains a data: URL in a style context; the rendered diagram was rejected.")
    }
    if ($Text -match '(?i)\bexpression\s*\(') {
        $Errors.Add("$Path contains a CSS expression; the rendered diagram was rejected.")
    }
    foreach ($match in [regex]::Matches($Text, '(?i)url\(\s*([^)]*)\)')) {
        $reference = $match.Groups[1].Value.Trim().Trim('"', "'")
        $scheme = Get-CrowUnsafeUrlScheme -Value $reference
        if ($scheme) {
            $Errors.Add("$Path contains a ${scheme}: URL in a style context; the rendered diagram was rejected.")
        }
        elseif ($reference -notmatch '^#[A-Za-z0-9_.:-]+$') {
            $Errors.Add("$Path contains an external CSS reference 'url($reference)'.")
        }
    }
}

function Test-CrowRenderedSvg {
    <#
    .SYNOPSIS
      Rejects rendered SVG that is not inert, self-contained markup.

    .DESCRIPTION
      The document is tokenized into markup and text before any check runs, so
      the checks apply to element names, attribute names, attribute values, and
      style bodies rather than to visible label text. Diagram labels such as
      'Data: pending' or 'Metadata: retained' are therefore accepted, exactly as
      Test-CrowMermaidSource accepts them in the source, while an active context
      is still rejected:

        - script, foreignObject, image, and embedded or animated elements;
        - event handler attributes, as XML attributes rather than as text;
        - javascript:, data:, and other active schemes in href, xlink:href, src,
          style, url(), and the other URL-bearing attributes;
        - references that are not same-document, including external use/href;
        - DOCTYPE and entity declarations, CDATA, and non-XML instructions;
        - @import and external url() in style elements and style attributes;
        - a '<' inside style element content, which valid CSS never needs and
          which would mean the tokenizer and a browser disagree about where the
          raw text ends.

      Every failure is reported and the caller rejects the diagram. Nothing is
      stripped, escaped, or repaired, and markup that cannot be parsed is a
      rejection rather than a pass.
    #>
    [CmdletBinding()]
    param(
        [AllowNull()][object]$Svg,
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][object]$Errors
    )

    if (-not ($Svg -is [string]) -or [string]::IsNullOrWhiteSpace($Svg)) {
        $Errors.Add("$Path produced no SVG output.")
        return
    }
    if ($Svg -notmatch '(?s)<svg[\s>].*</svg>') {
        $Errors.Add("$Path did not produce a complete <svg> element.")
        return
    }

    $styleDepth = 0
    foreach ($token in (Get-CrowMarkupToken -Markup $Svg)) {
        if ($token.Kind -eq 'malformed') {
            $Errors.Add("$Path contains markup that could not be parsed; the rendered diagram was rejected.")
            return
        }
        if ($token.Kind -eq 'comment') { continue }
        if ($token.Kind -eq 'cdata') {
            $Errors.Add("$Path contains a CDATA section; the rendered diagram was rejected.")
            continue
        }
        if ($token.Kind -eq 'declaration') {
            $reason = switch -Regex ($token.Name) {
                '(?i)^DOCTYPE$' { 'contains a DOCTYPE declaration'; break }
                '(?i)^ENTITY$' { 'contains an entity declaration'; break }
                default { "contains an unsupported '<!$($token.Name)' declaration" }
            }
            $Errors.Add("$Path $reason; the rendered diagram was rejected.")
            continue
        }
        if ($token.Kind -eq 'instruction') {
            if ($token.Name -cne 'xml') {
                $Errors.Add("$Path contains a '<?$($token.Name)' processing instruction; the rendered diagram was rejected.")
            }
            continue
        }
        if ($token.Kind -eq 'text') {
            # Text is only active inside a style element; label text is inert.
            if ($styleDepth -gt 0) {
                Test-CrowStyleValue -Text $token.Text -Path $Path -Errors $Errors -RawText
            }
            continue
        }

        $localName = (($token.Name -split ':')[-1]).ToLowerInvariant()
        if ($token.IsClosing) {
            if ($localName -eq 'style' -and $styleDepth -gt 0) { $styleDepth-- }
            continue
        }
        if ($script:CrowSvgForbiddenElements.Contains($localName)) {
            $Errors.Add("$Path $($script:CrowSvgForbiddenElements[$localName]); the rendered diagram was rejected.")
        }
        if ($localName -eq 'style' -and -not $token.IsSelfClosing) { $styleDepth++ }

        foreach ($attribute in (Get-CrowMarkupAttribute -Tag $token.Text)) {
            $attributeName = $attribute.Name.ToLowerInvariant()
            $attributeLocalName = ($attributeName -split ':')[-1]
            if ($attributeName -match '^on[a-z]' -or $attributeLocalName -match '^on[a-z]') {
                $Errors.Add("$Path contains an inline event handler attribute '$($attribute.Name)'; the rendered diagram was rejected.")
                continue
            }
            if ($script:CrowSvgUrlAttributes -contains $attributeName -or
                $script:CrowSvgUrlAttributes -contains $attributeLocalName) {
                $scheme = Get-CrowUnsafeUrlScheme -Value $attribute.Value
                if ($scheme) {
                    $Errors.Add("$Path contains a ${scheme}: URL in the '$($attribute.Name)' attribute; the rendered diagram was rejected.")
                }
                elseif ($attribute.Value -notmatch '^#[A-Za-z0-9_.:-]+$') {
                    $Errors.Add("$Path contains a reference that is not same-document: '$($attribute.Value)'.")
                }
                continue
            }
            if ($attributeLocalName -eq 'style' -or $attribute.Value -match '(?i)url\(') {
                Test-CrowStyleValue -Text $attribute.Value -Path $Path -Errors $Errors
            }
        }
    }
}

function Test-CrowSelfContainedHtml {
    <#
    .SYNOPSIS
      Confirms a rendered report loads no external subresource, uses only safe
      link schemes, and carries exactly the one inline script block the report
      template defines.

    .DESCRIPTION
      The document is tokenized before any check runs, so subresource, event
      handler, link, and CSS checks apply to element names, attribute names,
      attribute values, and style bodies rather than to visible prose. Report
      text such as 'the src= attribute', 'url(theme.png)', or
      'integrity = checked' is therefore accepted, while an actual subresource
      or unsafe URL in the same document is still rejected.

      Script blocks are counted structurally: the report template contributes
      exactly one attribute-free inline <script>, so any additional script
      element, a script with attributes, or a missing script is a rejection.
      Supply -ExpectedInlineScript to also require that the single block is
      byte-for-byte the bundled report script.

      Markup that cannot be parsed is a rejection rather than a pass. Nothing is
      stripped, escaped, or repaired.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Html,
        [Parameter(Mandatory)][object]$Errors,
        [AllowNull()][string]$ExpectedInlineScript
    )

    $forbiddenElements = @{
        'link'   = 'uses a link element'
        'iframe' = 'uses an embedded object element'
        'object' = 'uses an embedded object element'
        'embed'  = 'uses an embedded object element'
        'applet' = 'uses an embedded object element'
        'base'   = 'uses a base element'
        'frame'  = 'uses an embedded object element'
    }
    $subresourceAttributes = @{
        'src'        = 'uses a src attribute'
        'srcset'     = 'uses a srcset attribute'
        'integrity'  = 'references a subresource integrity hash'
        'data'       = 'uses an object data attribute'
        'poster'     = 'uses a poster attribute'
        'background' = 'uses a background attribute'
        'ping'       = 'uses a ping attribute'
        'manifest'   = 'uses a manifest attribute'
        'codebase'   = 'uses a codebase attribute'
        'archive'    = 'uses an archive attribute'
        'formaction' = 'uses a formaction attribute'
        'action'     = 'uses a form action attribute'
    }

    $scriptCount = 0
    $scriptBodies = New-Object 'System.Collections.Generic.List[string]'
    $styleDepth = 0
    $scriptDepth = 0

    foreach ($token in (Get-CrowMarkupToken -Markup $Html)) {
        if ($token.Kind -eq 'malformed') {
            $Errors.Add('Rendered HTML contains markup that could not be parsed; the report was rejected.')
            return
        }
        if ($token.Kind -eq 'text') {
            if ($styleDepth -gt 0) {
                Test-CrowStyleValue -Text $token.Text -Path 'Rendered HTML' -Errors $Errors -RawText
            }
            elseif ($scriptDepth -gt 0) {
                $scriptBodies.Add($token.Text)
            }
            continue
        }
        if ($token.Kind -eq 'cdata') {
            $Errors.Add('Rendered HTML contains a CDATA section, which browsers read as a bogus comment; the report was rejected.')
            continue
        }
        if ($token.Kind -eq 'declaration') {
            if ($token.Name -notmatch '(?i)^DOCTYPE$') {
                $Errors.Add("Rendered HTML contains an unsupported '<!$($token.Name)' declaration.")
            }
            continue
        }
        if ($token.Kind -eq 'instruction') {
            $Errors.Add("Rendered HTML contains a '<?$($token.Name)' processing instruction, which browsers read as a bogus comment; the report was rejected.")
            continue
        }
        if ($token.Kind -ne 'element') { continue }

        $localName = (($token.Name -split ':')[-1]).ToLowerInvariant()
        if ($token.IsClosing) {
            if ($localName -eq 'style' -and $styleDepth -gt 0) { $styleDepth-- }
            if ($localName -eq 'script' -and $scriptDepth -gt 0) { $scriptDepth-- }
            continue
        }
        if ($forbiddenElements.Contains($localName)) {
            $Errors.Add("Rendered HTML is not self-contained: it $($forbiddenElements[$localName]).")
        }
        if ($localName -eq 'script') {
            $scriptCount++
            if (-not $token.IsSelfClosing) { $scriptDepth++ }
            if (@(Get-CrowMarkupAttribute -Tag $token.Text).Count -gt 0) {
                $Errors.Add('Rendered HTML is not self-contained: its inline script element carries attributes.')
            }
        }
        if ($localName -eq 'style' -and -not $token.IsSelfClosing) { $styleDepth++ }

        foreach ($attribute in (Get-CrowMarkupAttribute -Tag $token.Text)) {
            $attributeName = $attribute.Name.ToLowerInvariant()
            $attributeLocalName = ($attributeName -split ':')[-1]
            if ($attributeName -match '^on[a-z]' -or $attributeLocalName -match '^on[a-z]') {
                $Errors.Add("Rendered HTML contains an inline event handler attribute '$($attribute.Name)'.")
                continue
            }
            if ($subresourceAttributes.Contains($attributeName) -or
                $subresourceAttributes.Contains($attributeLocalName)) {
                $reason = $subresourceAttributes[$attributeLocalName]
                if (-not $reason) { $reason = $subresourceAttributes[$attributeName] }
                $Errors.Add("Rendered HTML is not self-contained: it $reason.")
                continue
            }
            if ($attributeLocalName -eq 'href') {
                $reference = $attribute.Value.Trim()
                if ($reference -match '^#[A-Za-z0-9_.:-]*$') { continue }
                if ($reference -match '^https://[^\s"''<>\\]+$') { continue }
                $Errors.Add("Rendered HTML contains an unsafe or external href '$reference'.")
                continue
            }
            if ($attributeLocalName -eq 'style' -or $attribute.Value -match '(?i)url\(') {
                Test-CrowStyleValue -Text $attribute.Value -Path 'Rendered HTML' -Errors $Errors
            }
        }
    }

    if ($scriptCount -ne 1) {
        $Errors.Add("Rendered HTML must contain exactly the one inline script block defined by the report " +
            "template, but it contains $scriptCount script element(s).")
    }
    elseif ($PSBoundParameters.ContainsKey('ExpectedInlineScript') -and
        -not [string]::IsNullOrEmpty($ExpectedInlineScript) -and
        (($scriptBodies -join '') -cne $ExpectedInlineScript)) {
        $Errors.Add('Rendered HTML does not carry the bundled report script unchanged in its inline script block.')
    }

    foreach ($token in [regex]::Matches($Html, '\{\{[A-Za-z0-9_]+\}\}')) {
        $Errors.Add("Rendered HTML contains the unresolved placeholder '$($token.Value)'.")
    }
}

function Test-CrowRenderedMarkdown {
    <#
    .SYNOPSIS
      Confirms rendered Markdown resolved every placeholder and links only to
      same-document anchors or https URLs.

    .DESCRIPTION
      Link detection ignores an escaped ']' because block and cell escaping turn
      prose such as '[fee](applies)' into '\[fee\](applies)', which is literal
      text rather than a link. An unescaped ']( ...' is still a real link and is
      checked.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Markdown,
        [Parameter(Mandatory)][object]$Errors
    )

    foreach ($token in [regex]::Matches($Markdown, '\{\{[A-Za-z0-9_]+\}\}')) {
        $Errors.Add("Rendered Markdown contains the unresolved placeholder '$($token.Value)'.")
    }
    foreach ($match in [regex]::Matches($Markdown, '(?<!\\)\]\(\s*([^)\s]+)')) {
        $reference = $match.Groups[1].Value
        if ($reference -match '^#[A-Za-z0-9_.:-]*$') { continue }
        if ($reference -match '^https://[^\s"''<>\\]+$') { continue }
        $Errors.Add("Rendered Markdown contains an unsafe or external link '$reference'.")
    }
}

function Expand-CrowTemplate {
    <#
    .SYNOPSIS
      Replaces every template placeholder in a single pass so an inserted value
      is never rescanned as a placeholder.

    .DESCRIPTION
      Two placeholder forms are supported and are matched by one regular
      expression, so substitution happens exactly once per template position:

        {{NAME}}          text placeholders in Markdown and HTML;
        /*{{NAME}}*/      injection points inside <style> and <script>, which
                          keep the template valid static CSS and JavaScript.

      Unknown placeholders are left untouched so the post-render unresolved
      placeholder checks can report them.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][AllowEmptyString()][string]$Template,
        [Parameter(Mandatory)][System.Collections.IDictionary]$Values
    )

    $pattern = '/\*\{\{(?<key>[A-Za-z0-9_]+)\}\}\*/|\{\{(?<key>[A-Za-z0-9_]+)\}\}'
    $evaluator = {
        param($match)
        $key = $match.Groups['key'].Value
        if ($Values.Contains($key)) { return [string]$Values[$key] }
        return $match.Value
    }
    return [regex]::Replace($Template, $pattern, $evaluator)
}

function Test-CrowBusinessRuleLedger {
    <#
    .SYNOPSIS
      Compares regenerated data with the previously committed data file so
      stable identifiers cannot disappear, silently reactivate, or be reused.

    .DESCRIPTION
      Fails closed. Reactivating a retired identifier is an error unless the
      caller passes -AllowRetiredRuleReactivation, which records the accepted
      risk in the optional -Risks collection instead.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][AllowNull()][object]$PreviousData,
        [Parameter(Mandatory)][AllowNull()][object]$CurrentData,
        [switch]$AllowRetiredRuleReactivation,
        [Parameter(Mandatory)][object]$Errors,
        [AllowNull()][object]$Risks
    )

    $previousRules = @(Get-CrowArray (Get-CrowProperty $PreviousData 'rules'))
    if ($previousRules.Count -eq 0) {
        $Errors.Add('The previous data file records no rules, so it cannot be used as the identifier ledger.')
        return
    }

    $currentById = @{}
    foreach ($rule in @(Get-CrowArray (Get-CrowProperty $CurrentData 'rules'))) {
        $id = Get-CrowProperty $rule 'id'
        if (($id -is [string]) -and -not $currentById.ContainsKey($id)) {
            $currentById[$id] = $rule
        }
    }

    foreach ($previousRule in $previousRules) {
        $id = Get-CrowProperty $previousRule 'id'
        if (-not ($id -is [string])) {
            $Errors.Add('The previous data file contains a rule without a string id, so it cannot be used as the identifier ledger.')
            continue
        }
        if (-not $currentById.ContainsKey($id)) {
            $Errors.Add("Rule '$id' is recorded in the previous data file but is missing from the current one. " +
                'Identifiers are permanent: keep the rule and set its status to retired instead of deleting it.')
            continue
        }

        if ((Get-CrowProperty $previousRule 'status') -ne 'retired') { continue }

        $currentRule = $currentById[$id]
        $previousTitle = [string](Get-CrowProperty $previousRule 'title')
        $currentTitle = [string](Get-CrowProperty $currentRule 'title')
        if ($previousTitle -ne $currentTitle) {
            $Errors.Add("Retired rule '$id' now carries a different title ('$currentTitle' instead of '$previousTitle'). " +
                'Retired numbers are reserved and are never reused: give the replacement rule a new identifier.')
        }
        if ((Get-CrowProperty $currentRule 'status') -eq 'retired') { continue }

        if ($AllowRetiredRuleReactivation) {
            if ($null -ne $Risks) {
                $Risks.Add("Accepted risk: retired rule '$id' was reactivated under an explicit override. " +
                    'This is only correct when the identical rule was restored in the implementation; ' +
                    'a materially different rule must get a new identifier.')
            }
            continue
        }
        $Errors.Add("Retired rule '$id' is active again in the current data file. " +
            'Reactivation requires the explicit -AllowRetiredRuleReactivation override and is only correct when ' +
            'the identical rule was restored in the implementation; otherwise give the new rule a new identifier.')
    }
}

function ConvertTo-CrowHtmlText {
    <#
    .SYNOPSIS
      Encodes text for HTML element and quoted-attribute contexts.
    #>
    [CmdletBinding()]
    param([AllowNull()][object]$Value)

    return [System.Net.WebUtility]::HtmlEncode([string]$Value)
}

function ConvertTo-CrowMarkdownText {
    <#
    .SYNOPSIS
      Escapes Markdown control characters in block text.
    #>
    [CmdletBinding()]
    param([AllowNull()][object]$Value)

    $text = [string]$Value
    $text = $text.Replace("`r`n", "`n").Replace("`r", "`n")
    return [regex]::Replace($text, '([\\`*_\[\]<>|#~])', '\$1')
}

function ConvertTo-CrowMarkdownCell {
    <#
    .SYNOPSIS
      Escapes Markdown control characters for a single table cell.
    #>
    [CmdletBinding()]
    param([AllowNull()][object]$Value)

    $text = [regex]::Replace([string]$Value, '\s+', ' ').Trim()
    return ConvertTo-CrowMarkdownText $text
}

function ConvertTo-CrowPrefixedSvg {
    <#
    .SYNOPSIS
      Rewrites every SVG identifier with a deterministic per-diagram prefix so
      inlined diagrams cannot collide.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Svg,
        [Parameter(Mandatory)][string]$Prefix
    )

    $identifiers = New-Object 'System.Collections.Generic.List[string]'
    foreach ($match in [regex]::Matches($Svg, '\sid\s*=\s*"([^"]+)"')) {
        $value = $match.Groups[1].Value
        if (-not $identifiers.Contains($value)) { $identifiers.Add($value) }
    }

    $result = $Svg
    foreach ($identifier in $identifiers) {
        $escaped = [regex]::Escape($identifier)
        $replacement = "$Prefix$identifier"
        $result = [regex]::Replace($result, '(?<=\sid\s*=\s*")' + $escaped + '(?=")', $replacement)
        $result = [regex]::Replace($result, '(?<=\saria-labelledby\s*=\s*")' + $escaped + '(?=")', $replacement)
        $result = [regex]::Replace($result, '(?<=\saria-describedby\s*=\s*")' + $escaped + '(?=")', $replacement)
        $result = [regex]::Replace($result, '#' + $escaped + '(?![\w-])', "#$replacement")
    }
    return $result
}

function Set-CrowSvgAccessibleName {
    <#
    .SYNOPSIS
      Replaces root <svg> accessibility attributes with the figure's caption and
      description identifiers.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Svg,
        [Parameter(Mandatory)][string]$LabelledBy
    )

    $match = [regex]::Match($Svg, '^\s*<svg[^>]*>')
    if (-not $match.Success) { return $Svg }

    $tag = $match.Value.TrimStart()
    $tag = [regex]::Replace($tag, '\s(role|aria-labelledby|aria-describedby|aria-label|aria-roledescription)\s*=\s*"[^"]*"', '')
    $tag = [regex]::Replace($tag, '\s*/?>$', '')
    $tag = $tag + ' role="img" aria-labelledby="' + $LabelledBy + '">'
    return $tag + $Svg.Substring($match.Index + $match.Length)
}

function Move-CrowStagedDocument {
    <#
    .SYNOPSIS
      Performs the single destructive step of a publication: moving one verified
      staging file onto its target path.

    .DESCRIPTION
      Isolated so the failure window between deleting a target and moving its
      replacement into place is one named operation that the module's own tests
      can make fail deterministically, on every platform and without special
      file-system privileges.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Staging,
        [Parameter(Mandatory)][string]$Path
    )

    [System.IO.File]::Move($Staging, $Path)
}

function Write-CrowDocumentPair {
    <#
    .SYNOPSIS
      Publishes the generated documents together, or leaves every target
      unchanged.

    .DESCRIPTION
      Each document is normalized to UTF-8 (no BOM) with LF endings, written to
      a staging file beside its target, and read back and compared before any
      target is replaced. A failure while staging or verifying therefore
      publishes nothing.

      Existing targets are copied to a backup first. Replacement then happens in
      order, and each document is recorded as attempted before its target is
      deleted, so the window between a successful delete and a failed move is
      covered as well: if any replacement fails, every attempted document is
      restored from its backup and attempted documents that did not exist before
      are removed. The run therefore cannot leave a mixed old and new pair
      behind, and it cannot leave a document missing entirely.

      A restore is verified against the backup rather than assumed. Staging and
      backup files are removed on every path, except that a backup is kept, with
      a warning, when its document could not be restored and verified; the
      original failure is always the one reported.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param([Parameter(Mandatory)][System.Collections.IDictionary]$Documents)

    if ($Documents.Count -eq 0) { return }

    $encoding = [System.Text.UTF8Encoding]::new($false)
    $plan = New-Object 'System.Collections.Generic.List[object]'
    foreach ($key in $Documents.Keys) {
        $path = [string]$key
        if (Test-Path -LiteralPath $path -PathType Container) {
            throw ("Cannot publish '$path': a directory already exists at that path. " +
                'No output files were written.')
        }
        $directory = Split-Path -Parent $path
        if ($directory -and -not (Test-Path -LiteralPath $directory)) {
            New-Item -ItemType Directory -Path $directory -Force | Out-Null
        }
        $suffix = [guid]::NewGuid().ToString('N')
        $plan.Add([pscustomobject]@{
                Path          = $path
                Content       = ([string]$Documents[$key]).Replace("`r`n", "`n").Replace("`r", "`n")
                Staging       = "$path.$suffix.tmp"
                Backup        = "$path.$suffix.bak"
                Existed       = (Test-Path -LiteralPath $path -PathType Leaf)
                RestoreFailed = $false
            })
    }

    if (-not $PSCmdlet.ShouldProcess(
            (@($plan | ForEach-Object { $_.Path }) -join ', '),
            'Publish generated business-rule documents')) {
        return
    }

    $attempted = New-Object 'System.Collections.Generic.List[object]'
    try {
        foreach ($item in $plan) {
            [System.IO.File]::WriteAllText($item.Staging, $item.Content, $encoding)
            if ([System.IO.File]::ReadAllText($item.Staging) -cne $item.Content) {
                throw ("Staged document '$($item.Path)' did not match the generated content when read back. " +
                    'No output files were written.')
            }
            if ($item.Existed) {
                [System.IO.File]::Copy($item.Path, $item.Backup, $true)
            }
        }
        foreach ($item in $plan) {
            # Record the attempt before the destructive step. A failure between
            # the delete and the move would otherwise leave the document with no
            # copy anywhere: not restored here, and its backup discarded below.
            $attempted.Add($item)
            if ($item.Existed) { [System.IO.File]::Delete($item.Path) }
            Move-CrowStagedDocument -Staging $item.Staging -Path $item.Path
        }
    }
    catch {
        foreach ($item in $attempted) {
            try {
                if ($item.Existed) {
                    [System.IO.File]::Copy($item.Backup, $item.Path, $true)
                    # Confirm the restore rather than assume it: the backup is
                    # the only remaining copy and must not be discarded on the
                    # strength of a call that returned without writing.
                    $restored = New-Object System.IO.FileInfo $item.Path
                    $backup = New-Object System.IO.FileInfo $item.Backup
                    if (-not $restored.Exists -or $restored.Length -ne $backup.Length) {
                        throw 'the restored file does not match the backup'
                    }
                }
                elseif (Test-Path -LiteralPath $item.Path -PathType Leaf) {
                    [System.IO.File]::Delete($item.Path)
                }
            }
            catch {
                # Never mask the original failure, and never discard the only
                # remaining copy of the replaced document.
                $item.RestoreFailed = $true
                Write-Warning ("Could not restore '$($item.Path)' after a failed publication: " +
                    "$($_.Exception.Message). The previous document is kept at '$($item.Backup)'.")
            }
        }
        throw
    }
    finally {
        foreach ($item in $plan) {
            $temporaryPaths = @($item.Staging)
            if (-not $item.RestoreFailed) { $temporaryPaths += $item.Backup }
            foreach ($temporaryPath in $temporaryPaths) {
                if (Test-Path -LiteralPath $temporaryPath -PathType Leaf) {
                    Remove-Item -LiteralPath $temporaryPath -Force -ErrorAction SilentlyContinue
                }
            }
        }
    }
}

function Test-CrowBusinessRuleData {
    <#
    .SYNOPSIS
      Validates parsed business-rules-data.json against the authoritative
      contract and returns every failure as a string.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][AllowNull()][object]$Data)

    $contract = Get-CrowBusinessRuleContract
    $errors = New-Object 'System.Collections.Generic.List[string]'

    if (-not (Test-CrowObjectShape -Object $Data -Path 'data' -Required $contract.RootRequired -Optional $contract.RootOptional -Errors $errors)) {
        return $errors.ToArray()
    }

    Test-CrowText -Value (Get-CrowProperty $Data 'schema_version') -Path 'data.schema_version' -AllowedValues @($contract.SchemaVersion) -Errors $errors
    Test-CrowText -Value (Get-CrowProperty $Data 'generated') -Path 'data.generated' -Pattern $contract.DatePattern -Errors $errors

    $application = Get-CrowProperty $Data 'application'
    if (Test-CrowObjectShape -Object $application -Path 'data.application' -Required $contract.ApplicationRequired -Optional $contract.ApplicationOptional -Errors $errors) {
        Test-CrowText -Value (Get-CrowProperty $application 'name') -Path 'data.application.name' -Errors $errors
        Test-CrowText -Value (Get-CrowProperty $application 'scope') -Path 'data.application.scope' -Errors $errors
        Test-CrowText -Value (Get-CrowProperty $application 'repository') -Path 'data.application.repository' -Errors $errors
        Test-CrowText -Value (Get-CrowProperty $application 'commit') -Path 'data.application.commit' -Pattern $contract.CommitPattern -Errors $errors
        Test-CrowText -Value (Get-CrowProperty $application 'acronym') -Path 'data.application.acronym' -Optional -Errors $errors
        Test-CrowText -Value (Get-CrowProperty $application 'scope_note') -Path 'data.application.scope_note' -Optional -Errors $errors
    }

    $sourceIds = New-Object 'System.Collections.Generic.List[string]'
    $availableSourceIds = New-Object 'System.Collections.Generic.List[string]'
    $unavailableSources = 0
    $sources = @(Get-CrowArray (Get-CrowProperty $Data 'documentation_sources'))
    for ($index = 0; $index -lt $sources.Count; $index++) {
        $source = $sources[$index]
        $path = "data.documentation_sources[$index]"
        if (-not (Test-CrowObjectShape -Object $source -Path $path -Required $contract.SourceRequired -Optional $contract.SourceOptional -Errors $errors)) {
            continue
        }
        $id = Get-CrowProperty $source 'id'
        Test-CrowText -Value $id -Path "$path.id" -Pattern $contract.SourceIdPattern -Errors $errors
        if ($id -is [string]) {
            if ($sourceIds.Contains($id)) { $errors.Add("$path.id '$id' is duplicated.") }
            else { $sourceIds.Add($id) }
        }
        Test-CrowText -Value (Get-CrowProperty $source 'title') -Path "$path.title" -Errors $errors
        Test-CrowText -Value (Get-CrowProperty $source 'location') -Path "$path.location" -Errors $errors
        Test-CrowText -Value (Get-CrowProperty $source 'note') -Path "$path.note" -Optional -Errors $errors
        Test-CrowText -Value (Get-CrowProperty $source 'kind') -Path "$path.kind" -AllowedValues $contract.SourceKinds -Errors $errors
        $status = Get-CrowProperty $source 'status'
        Test-CrowText -Value $status -Path "$path.status" -AllowedValues $contract.SourceStatuses -Errors $errors
        if ($status -eq 'unavailable') { $unavailableSources++ }
        elseif (($status -eq 'available') -and ($id -is [string])) { $availableSourceIds.Add($id) }
    }

    $gap = Get-CrowProperty $Data 'documentation_gap'
    if (Test-CrowObjectShape -Object $gap -Path 'data.documentation_gap' -Required $contract.GapRequired -Optional $contract.GapOptional -Errors $errors) {
        $present = Get-CrowProperty $gap 'present'
        if (-not ($present -is [bool])) {
            $errors.Add('data.documentation_gap.present must be true or false.')
        }
        elseif ($present) {
            Test-CrowText -Value (Get-CrowProperty $gap 'summary') -Path 'data.documentation_gap.summary' -Errors $errors
            Test-CrowText -Value (Get-CrowProperty $gap 'coverage_impact') -Path 'data.documentation_gap.coverage_impact' -Errors $errors
        }
        elseif ($sources.Count -eq 0 -or $unavailableSources -gt 0) {
            $errors.Add('data.documentation_gap.present must be true when guides or training documentation are missing or unavailable, so the reduced reconciliation coverage is reported.')
        }
    }

    $facetIds = New-Object 'System.Collections.Generic.List[string]'
    $groupIds = New-Object 'System.Collections.Generic.List[string]'
    $facetElementIds = @{}
    $groups = @(Get-CrowArray (Get-CrowProperty $Data 'facet_groups'))
    if ($groups.Count -eq 0) { $errors.Add('data.facet_groups must declare at least one group.') }
    for ($index = 0; $index -lt $groups.Count; $index++) {
        $group = $groups[$index]
        $path = "data.facet_groups[$index]"
        if (-not (Test-CrowObjectShape -Object $group -Path $path -Required $contract.GroupRequired -Optional $contract.GroupOptional -Errors $errors)) {
            continue
        }
        $groupId = Get-CrowProperty $group 'id'
        Test-CrowText -Value $groupId -Path "$path.id" -Pattern $contract.GroupIdPattern -Errors $errors
        if ($groupId -is [string]) {
            if ($groupIds.Contains($groupId)) { $errors.Add("$path.id '$groupId' is duplicated.") }
            else { $groupIds.Add($groupId) }
        }
        Test-CrowText -Value (Get-CrowProperty $group 'label') -Path "$path.label" -Errors $errors
        Test-CrowText -Value (Get-CrowProperty $group 'description') -Path "$path.description" -Optional -Errors $errors

        $facets = @(Get-CrowArray (Get-CrowProperty $group 'facets'))
        if ($facets.Count -eq 0) { $errors.Add("$path.facets must declare at least one facet.") }
        for ($facetIndex = 0; $facetIndex -lt $facets.Count; $facetIndex++) {
            $facet = $facets[$facetIndex]
            $facetPath = "$path.facets[$facetIndex]"
            if (-not (Test-CrowObjectShape -Object $facet -Path $facetPath -Required $contract.FacetRequired -Optional $contract.FacetOptional -Errors $errors)) {
                continue
            }
            $facetId = Get-CrowProperty $facet 'id'
            Test-CrowText -Value $facetId -Path "$facetPath.id" -Pattern $contract.FacetIdPattern -Errors $errors
            if ($facetId -is [string]) {
                if ($facetIds.Contains($facetId)) { $errors.Add("$facetPath.id '$facetId' is duplicated.") }
                else { $facetIds.Add($facetId) }
                if (($groupId -is [string]) -and ($facetId -notlike "$groupId.*")) {
                    $errors.Add("$facetPath.id '$facetId' must start with the group id '$groupId'.")
                }

                # The HTML report derives a checkbox element id from the facet id,
                # so two facet ids that normalize to the same element id would
                # break label association. Fail here, before any diagram is
                # rendered, rather than at the post-render duplicate-id check.
                $elementId = 'facet-' + $facetId.Replace('.', '-')
                if ($facetElementIds.ContainsKey($elementId)) {
                    $errors.Add("$facetPath.id '$facetId' collides with '$($facetElementIds[$elementId])' " +
                        "because both produce the HTML element id '$elementId'.")
                }
                else { $facetElementIds[$elementId] = $facetId }
            }
            Test-CrowText -Value (Get-CrowProperty $facet 'label') -Path "$facetPath.label" -Errors $errors
            Test-CrowText -Value (Get-CrowProperty $facet 'description') -Path "$facetPath.description" -Optional -Errors $errors
        }
    }

    $ruleIds = New-Object 'System.Collections.Generic.List[string]'
    $rules = @(Get-CrowArray (Get-CrowProperty $Data 'rules'))
    if ($rules.Count -eq 0) { $errors.Add('data.rules must contain at least one rule.') }
    for ($index = 0; $index -lt $rules.Count; $index++) {
        $rule = $rules[$index]
        $path = "data.rules[$index]"
        if (-not (Test-CrowObjectShape -Object $rule -Path $path -Required $contract.RuleRequired -Optional $contract.RuleOptional -Errors $errors)) {
            continue
        }

        $ruleId = Get-CrowProperty $rule 'id'
        Test-CrowText -Value $ruleId -Path "$path.id" -Pattern $contract.RuleIdPattern -Errors $errors
        if ($ruleId -is [string]) {
            if ($ruleIds.Contains($ruleId)) {
                $errors.Add("$path.id '$ruleId' is duplicated; business rule identifiers are stable and are never reused.")
            }
            else { $ruleIds.Add($ruleId) }
        }
        Test-CrowText -Value (Get-CrowProperty $rule 'title') -Path "$path.title" -Errors $errors
        Test-CrowText -Value (Get-CrowProperty $rule 'statement') -Path "$path.statement" -Errors $errors
        Test-CrowText -Value (Get-CrowProperty $rule 'rationale') -Path "$path.rationale" -Optional -Errors $errors
        Test-CrowText -Value (Get-CrowProperty $rule 'category') -Path "$path.category" -AllowedValues $contract.Categories -Errors $errors
        $status = Get-CrowProperty $rule 'status'
        Test-CrowText -Value $status -Path "$path.status" -AllowedValues $contract.RuleStatuses -Errors $errors

        $facetRefs = @(Get-CrowArray (Get-CrowProperty $rule 'facets'))
        if ($facetRefs.Count -eq 0) { $errors.Add("$path.facets must reference at least one facet.") }
        foreach ($facetRef in $facetRefs) {
            if (-not ($facetRef -is [string])) {
                $errors.Add("$path.facets must contain facet id strings.")
                continue
            }
            if (-not $facetIds.Contains($facetRef)) {
                $errors.Add("$path.facets references unknown facet '$facetRef'.")
            }
        }

        $citations = @(Get-CrowArray (Get-CrowProperty $rule 'citations'))
        for ($citationIndex = 0; $citationIndex -lt $citations.Count; $citationIndex++) {
            $citation = $citations[$citationIndex]
            $citationPath = "$path.citations[$citationIndex]"
            if (-not (Test-CrowObjectShape -Object $citation -Path $citationPath -Required $contract.CitationRequired -Optional $contract.CitationOptional -Errors $errors)) {
                continue
            }
            $filePath = Get-CrowProperty $citation 'path'
            Test-CrowText -Value $filePath -Path "$citationPath.path" -Pattern $contract.CitationPathPattern -Errors $errors
            if (($filePath -is [string]) -and (
                    $filePath -match '(^|/)\.\.(/|$)' -or
                    $filePath -match '^[A-Za-z]:' -or
                    $filePath.StartsWith('/'))) {
                $errors.Add("$citationPath.path must be a repository-relative path without parent traversal.")
            }
            Test-CrowText -Value (Get-CrowProperty $citation 'symbol') -Path "$citationPath.symbol" -Errors $errors
            Test-CrowText -Value (Get-CrowProperty $citation 'commit') -Path "$citationPath.commit" -Pattern $contract.CommitPattern -Errors $errors
            $line = Get-CrowProperty $citation 'line'
            if ($null -ne $line) {
                $parsed = 0L
                $lineText = [Convert]::ToString($line, [Globalization.CultureInfo]::InvariantCulture)
                if (-not [long]::TryParse(
                        $lineText,
                        [Globalization.NumberStyles]::Integer,
                        [Globalization.CultureInfo]::InvariantCulture,
                        [ref]$parsed) -or $parsed -lt 1) {
                    $errors.Add("$citationPath.line must be a positive integer.")
                }
            }
        }

        $documentationRefs = @(Get-CrowArray (Get-CrowProperty $rule 'documentation_refs'))
        foreach ($documentationRef in $documentationRefs) {
            if (-not ($documentationRef -is [string])) {
                $errors.Add("$path.documentation_refs must contain documentation source id strings.")
                continue
            }
            if (-not $sourceIds.Contains($documentationRef)) {
                $errors.Add("$path.documentation_refs references unknown documentation source '$documentationRef'.")
            }
        }

        $matchNotes = @(Get-CrowArray (Get-CrowProperty $rule 'match_notes'))
        for ($noteIndex = 0; $noteIndex -lt $matchNotes.Count; $noteIndex++) {
            $note = $matchNotes[$noteIndex]
            $notePath = "$path.match_notes[$noteIndex]"
            if (-not (Test-CrowObjectShape -Object $note -Path $notePath -Required $contract.MatchNoteRequired -Optional $contract.MatchNoteOptional -Errors $errors)) {
                continue
            }
            $noteFacet = Get-CrowProperty $note 'facet'
            Test-CrowText -Value $noteFacet -Path "$notePath.facet" -Errors $errors
            Test-CrowText -Value (Get-CrowProperty $note 'reason') -Path "$notePath.reason" -Errors $errors
            if (($noteFacet -is [string]) -and ($facetRefs -notcontains $noteFacet)) {
                $errors.Add("$notePath.facet '$noteFacet' is not one of the rule's facets.")
            }
        }

        $reconciliation = Get-CrowProperty $rule 'reconciliation'
        if (Test-CrowObjectShape -Object $reconciliation -Path "$path.reconciliation" -Required $contract.ReconciliationRequired -Optional $contract.ReconciliationOptional -Errors $errors) {
            $classification = Get-CrowProperty $reconciliation 'classification'
            Test-CrowText -Value $classification -Path "$path.reconciliation.classification" -AllowedValues $contract.Classifications -Errors $errors
            $reconciliationNote = Get-CrowProperty $reconciliation 'note'
            if ($classification -eq 'aligned') {
                Test-CrowText -Value $reconciliationNote -Path "$path.reconciliation.note" -Optional -Errors $errors
            }
            else {
                Test-CrowText -Value $reconciliationNote -Path "$path.reconciliation.note" -Errors $errors
            }

            if ($classification -eq 'documented-only') {
                if ($documentationRefs.Count -eq 0) {
                    $errors.Add("$path is documented-only and must cite at least one documentation source.")
                }
            }
            elseif ($classification -eq 'unverifiable') {
                if ($citations.Count -eq 0 -and $documentationRefs.Count -eq 0) {
                    $errors.Add("$path is unverifiable and must record the code or documentation evidence that was inspected.")
                }
            }
            elseif ($contract.Classifications -contains $classification) {
                if ($citations.Count -eq 0) {
                    $errors.Add("$path must cite at least one implementation location for classification '$classification'.")
                }
                if ($classification -eq 'aligned' -or $classification -eq 'conflicting') {
                    $availableRefs = @($documentationRefs | Where-Object { $availableSourceIds.Contains($_) })
                    if ($documentationRefs.Count -eq 0 -or $availableRefs.Count -eq 0) {
                        $errors.Add("$path uses classification '$classification' and must reference at least one " +
                            "documentation source with status 'available'; comparing against documentation that was " +
                            "not inspected is not a comparison. Use classification 'unverifiable' with a note instead.")
                    }
                }
            }
        }

        $retirement = Get-CrowProperty $rule 'retirement'
        if ($status -eq 'retired') {
            if ($null -eq $retirement) {
                $errors.Add("$path is retired and must record retirement details; the identifier stays reserved.")
            }
            elseif (Test-CrowObjectShape -Object $retirement -Path "$path.retirement" -Required $contract.RetirementRequired -Optional $contract.RetirementOptional -Errors $errors) {
                Test-CrowText -Value (Get-CrowProperty $retirement 'retired_on') -Path "$path.retirement.retired_on" -Pattern $contract.DatePattern -Errors $errors
                Test-CrowText -Value (Get-CrowProperty $retirement 'reason') -Path "$path.retirement.reason" -Errors $errors
            }
        }
        elseif ($null -ne $retirement) {
            $errors.Add("$path records retirement details but is not retired.")
        }
    }

    $diagramIds = New-Object 'System.Collections.Generic.List[string]'
    $diagrams = @(Get-CrowArray (Get-CrowProperty $Data 'diagrams'))
    for ($index = 0; $index -lt $diagrams.Count; $index++) {
        $diagram = $diagrams[$index]
        $path = "data.diagrams[$index]"
        if (-not (Test-CrowObjectShape -Object $diagram -Path $path -Required $contract.DiagramRequired -Optional $contract.DiagramOptional -Errors $errors)) {
            continue
        }
        $diagramId = Get-CrowProperty $diagram 'id'
        Test-CrowText -Value $diagramId -Path "$path.id" -Pattern $contract.DiagramIdPattern -Errors $errors
        if ($diagramId -is [string]) {
            if ($diagramIds.Contains($diagramId)) { $errors.Add("$path.id '$diagramId' is duplicated.") }
            else { $diagramIds.Add($diagramId) }
        }
        Test-CrowText -Value (Get-CrowProperty $diagram 'title') -Path "$path.title" -Errors $errors
        Test-CrowText -Value (Get-CrowProperty $diagram 'description') -Path "$path.description" -Errors $errors
        Test-CrowMermaidSource -Source (Get-CrowProperty $diagram 'mermaid') -Path "$path.mermaid" -Errors $errors

        $ruleRefs = @(Get-CrowArray (Get-CrowProperty $diagram 'rule_refs'))
        if ($ruleRefs.Count -eq 0) { $errors.Add("$path.rule_refs must reference at least one rule.") }
        foreach ($ruleRef in $ruleRefs) {
            if (-not ($ruleRef -is [string])) {
                $errors.Add("$path.rule_refs must contain rule id strings.")
                continue
            }
            if (-not $ruleIds.Contains($ruleRef)) {
                $errors.Add("$path.rule_refs references unknown rule '$ruleRef'.")
            }
        }
    }

    $openQuestions = @(Get-CrowArray (Get-CrowProperty $Data 'open_questions'))
    for ($index = 0; $index -lt $openQuestions.Count; $index++) {
        Test-CrowText -Value $openQuestions[$index] -Path "data.open_questions[$index]" -Errors $errors
    }

    foreach ($entry in (Get-CrowDataString -Node $Data -Path 'data')) {
        # Mermaid source is exempt from the fenced-code check only: its own
        # security checks run in Test-CrowMermaidSource, but placeholders and
        # control characters are never acceptable anywhere in the data.
        if (($entry.Path -notlike 'data.diagrams*.mermaid') -and $entry.Value.Contains('```')) {
            $errors.Add("$($entry.Path) contains a fenced code block; business-rule data records citations, never source snippets.")
        }
        if ($entry.Value -match '\{\{[^}]*\}\}') {
            $errors.Add("$($entry.Path) contains an unresolved placeholder: '$($entry.Value)'.")
        }
        if ($entry.Value -match '[\x00-\x08\x0B\x0C\x0E-\x1F]') {
            $errors.Add("$($entry.Path) contains control characters.")
        }
    }

    return $errors.ToArray()
}

Export-ModuleMember -Function @(
    'Get-CrowBusinessRuleContract',
    'Get-CrowProperty',
    'Get-CrowDataString',
    'Get-CrowArray',
    'Test-CrowObjectShape',
    'Test-CrowText',
    'Test-CrowBusinessRuleData',
    'Test-CrowBusinessRuleLedger',
    'Test-CrowMermaidSource',
    'Test-CrowRenderedSvg',
    'Test-CrowSelfContainedHtml',
    'Test-CrowRenderedMarkdown',
    'Expand-CrowTemplate',
    'ConvertTo-CrowHtmlText',
    'ConvertTo-CrowMarkdownText',
    'ConvertTo-CrowMarkdownCell',
    'ConvertTo-CrowPrefixedSvg',
    'Set-CrowSvgAccessibleName',
    'Write-CrowDocumentPair'
)
