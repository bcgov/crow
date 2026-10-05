$ErrorActionPreference = 'Stop'
$scriptRoot = $PSScriptRoot
$graphScript = Join-Path $scriptRoot 'CrowAssetDependencyGraph.ps1'
$fixtureRoot = Join-Path ([System.IO.Path]::GetTempPath()) (
    'crow-asset-dependency-graph-' + [guid]::NewGuid().ToString('N'))
$utf8 = [System.Text.UTF8Encoding]::new($false)

function Write-FixtureFile {
    param(
        [string]$Path,
        [string]$Content
    )

    $parent = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $parent -PathType Container)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    [System.IO.File]::WriteAllText($Path, $Content, $utf8)
}

function Assert-HasError {
    param(
        [string[]]$Errors,
        [string]$ExpectedText,
        [string]$Scenario
    )

    if (@($Errors | Where-Object { $_.Contains($ExpectedText) }).Count -eq 0) {
        throw "$Scenario did not report '$ExpectedText'. Errors: $($Errors -join ' | ')"
    }
    Write-Information -MessageData "Passed: $Scenario" -InformationAction Continue
}

try {
    . $graphScript

    $agentPath = Join-Path $fixtureRoot '.apm/agents/crow-test.agent.md'
    $mainSkillPath = Join-Path $fixtureRoot '.apm/skills/crow-main/SKILL.md'
    $mainModulePath = Join-Path $fixtureRoot '.apm/skills/crow-main/modules/main.md'
    $supportSkillPath = Join-Path $fixtureRoot '.apm/skills/crow-support/SKILL.md'
    $supportModulePath = Join-Path $fixtureRoot '.apm/skills/crow-support/modules/support.md'
    $supportScriptPath = Join-Path $fixtureRoot '.apm/skills/crow-support/scripts/support.mjs'
    $rootReadmePath = Join-Path $fixtureRoot 'README.md'
    $guidePath = Join-Path (Split-Path -Parent $mainModulePath) 'guide-v2-(draft).md'
    $spacedGuidePath = Join-Path (Split-Path -Parent $mainModulePath) 'guide (v2).md'
    $escapedGuidePath = Join-Path (Split-Path -Parent $mainModulePath) 'guide-(escaped).md'
    $nestedLabelGuidePath = Join-Path (Split-Path -Parent $mainModulePath) 'nested-label.md'
    $manifestPath = Join-Path $fixtureRoot 'collections/fixture/apm.yml'

    Write-FixtureFile -Path $agentPath -Content @'
---
name: 'Crow Graph Test Agent'
description: 'Synthetic agent for dependency graph tests.'
tools: ['read']
---

# Crow Graph Test Agent

## Core Principles

The `crow-main` skill should be loaded before proceeding.
The `crow-main` skill will be used for this route.
[Main skill](../skills/crow-main/SKILL.md)
'@
    Write-FixtureFile -Path $mainSkillPath -Content @'
---
name: crow-main
description: Synthetic main skill for graph tests.
---

[Main module](modules/main.md)
Load the `crow-support` skill when the routed module is needed.
'@
    Write-FixtureFile -Path $mainModulePath -Content '# Main module'
    Write-FixtureFile -Path $supportSkillPath -Content @'
---
name: crow-support
description: Synthetic support skill for graph tests.
---

[Support module](modules/support.md)
'@
    $supportModuleContent = '[Support script](../scripts/support.mjs)'
    Write-FixtureFile -Path $supportModulePath -Content $supportModuleContent
    Write-FixtureFile -Path $supportScriptPath -Content 'export {}'
    Write-FixtureFile -Path $guidePath -Content '# Nested-parenthesis guide'
    Write-FixtureFile -Path $spacedGuidePath -Content '# Guide v2'
    Write-FixtureFile -Path $escapedGuidePath -Content '# Escaped-parenthesis guide'
    Write-FixtureFile -Path $nestedLabelGuidePath -Content '# Nested-label guide'
    Write-FixtureFile -Path $rootReadmePath -Content @'
# Root-relative link fixture

[Root skill](/.apm/skills/crow-main/SKILL.md)
'@

    $incompleteManifest = @'
name: bcgov-crow-fixture
version: 0.1.0
dependencies:
  apm:
    - git: https://github.com/bcgov/crow.git
      path: .apm/agents/crow-test.agent.md
      ref: v0.1.0
    - git: https://github.com/bcgov/crow.git
      path: .apm/skills/crow-main
      ref: v0.1.0
'@
    Write-FixtureFile -Path $manifestPath -Content $incompleteManifest

    $report = Get-CrowAssetDependencyReport -RepoRoot $fixtureRoot
    $mainToSupportEdge = @($report.Graph.Edges | Where-Object {
        $_.From -eq '.apm/skills/crow-main/SKILL.md' -and
        $_.To -eq '.apm/skills/crow-support/SKILL.md' -and
        $_.Kind -eq 'SkillReference'
    })
    if ($mainToSupportEdge.Count -eq 0) {
        throw 'The dependency graph did not include the transitive skill reference.'
    }
    Assert-HasError `
        -Errors $report.Errors `
        -ExpectedText "Collection 'fixture' is missing required skill/module '.apm/skills/crow-support/SKILL.md'" `
        -Scenario 'Reports a transitively required skill missing from a collection'

    $supportDependency = "    - git: https://github.com/bcgov/crow.git$([Environment]::NewLine)" +
        "      path: .apm/skills/crow-support$([Environment]::NewLine)" +
        '      ref: v0.1.0'
    $mainSkillOnlyManifest = [regex]::Replace(
        $incompleteManifest,
        '(?m)^(      path: )\.apm/skills/crow-main\r?$',
        '$1.apm/skills/crow-main/SKILL.md').TrimEnd() +
        [Environment]::NewLine + $supportDependency
    Write-FixtureFile -Path $manifestPath -Content $mainSkillOnlyManifest
    $report = Get-CrowAssetDependencyReport -RepoRoot $fixtureRoot
    Assert-HasError `
        -Errors $report.Errors `
        -ExpectedText "Collection 'fixture' is missing required skill/module '.apm/skills/crow-main/modules/main.md'" `
        -Scenario 'Reports a required module missing when a collection bundles only its skill entrypoint'

    Write-FixtureFile -Path $manifestPath -Content $incompleteManifest
    $report = Get-CrowAssetDependencyReport -RepoRoot $fixtureRoot
    $agentSkillEdge = @($report.Graph.Edges | Where-Object {
        $_.From -eq '.apm/agents/crow-test.agent.md' -and
        $_.To -eq '.apm/skills/crow-main/SKILL.md' -and
        $_.Kind -eq 'SkillReference'
    })
    if ($agentSkillEdge.Count -eq 0) {
        throw 'The dependency graph did not include the agent-to-skill edge.'
    }
    Write-Information `
        -MessageData 'Passed: Builds agent, skill, and module dependency edges' `
        -InformationAction Continue

    $completeManifest = $incompleteManifest.TrimEnd() +
        [Environment]::NewLine + $supportDependency
    Write-FixtureFile -Path $manifestPath -Content $completeManifest

    Write-FixtureFile -Path $mainModulePath -Content @'
# Main module

[External reference](https://example.com)
[Guide](guide-v2-(draft).md)
[`Code-styled label`](guide-v2-(draft).md)
[Escaped parentheses](guide-\(escaped\).md)
[outer [inner]](nested-label.md)
[Titled guide](<guide (v2).md> 'guide title')
[Guide definition]: <guide (v2).md> 'guide title'
  - [List guide](guide-v2-(draft).md)
`[Inline example](missing-inline.md)`
The `crow-support` skill is mentioned here without a routing action.

```markdown
[Fenced example](missing-fenced.md)
Load the `crow-fenced-skill` skill.
``` not a closing fence
[Still fenced](missing-after-invalid-close.md)
```

> ```markdown
> [Blockquoted fenced example](missing-blockquote.md)
> Load the `crow-blockquoted-skill` skill.
```

    [Indented code example](missing-indented.md)
    Load the `crow-indented-skill` skill.
    - [Indented list-code example](missing-indented-list.md)
'@
    $report = Get-CrowAssetDependencyReport -RepoRoot $fixtureRoot
    if ($report.Errors.Count -ne 0) {
        throw "A complete dependency closure produced errors: $($report.Errors -join ' | ')"
    }
    foreach ($expectedTarget in @(
            '.apm/skills/crow-main/modules/guide-(escaped).md',
            '.apm/skills/crow-main/modules/nested-label.md')) {
        $parsedLink = @($report.Graph.Edges | Where-Object {
            $_.From -eq '.apm/skills/crow-main/modules/main.md' -and
            $_.To -eq $expectedTarget -and
            $_.Kind -eq 'MarkdownLink'
        })
        if ($parsedLink.Count -eq 0) {
            throw "The dependency graph did not parse the expected Markdown link to '$expectedTarget'."
        }
    }
    $nonRoutingSkillEdge = @($report.Graph.Edges | Where-Object {
        $_.From -eq '.apm/skills/crow-main/modules/main.md' -and
        $_.To -eq '.apm/skills/crow-support/SKILL.md' -and
        $_.Kind -eq 'SkillReference'
    })
    if ($nonRoutingSkillEdge.Count -ne 0) {
        throw 'The dependency graph treated a non-routing mention as a required skill reference.'
    }
    Write-Information `
        -MessageData 'Passed: Accepts a collection with complete transitive skill and module coverage' `
        -InformationAction Continue

    $caseSkillPath = Join-Path $fixtureRoot '.apm/skills/crow-case/SKILL.md'
    $caseUpperGuidePath = Join-Path $fixtureRoot '.apm/skills/crow-case/Guide.md'
    $caseLowerGuidePath = Join-Path $fixtureRoot '.apm/skills/crow-case/guide.md'
    Write-FixtureFile -Path $caseSkillPath -Content @'
---
name: crow-case
description: Synthetic case-sensitive path fixture.
---

[Lowercase guide](guide.md)
'@
    Write-FixtureFile -Path $caseUpperGuidePath -Content '# Uppercase guide'
    if (-not (Test-Path -LiteralPath $caseLowerGuidePath -PathType Leaf)) {
        Write-FixtureFile -Path $caseLowerGuidePath -Content '# Lowercase guide'
        $caseSkillDependency = "    - git: https://github.com/bcgov/crow.git$([Environment]::NewLine)" +
            "      path: .apm/skills/crow-case/SKILL.md$([Environment]::NewLine)" +
            '      ref: v0.1.0'
        $caseGuideDependency = "    - git: https://github.com/bcgov/crow.git$([Environment]::NewLine)" +
            "      path: .apm/skills/crow-case/Guide.md$([Environment]::NewLine)" +
            '      ref: v0.1.0'
        $caseManifest = $completeManifest.TrimEnd() +
            [Environment]::NewLine + $caseSkillDependency +
            [Environment]::NewLine + $caseGuideDependency
        Write-FixtureFile -Path $manifestPath -Content $caseManifest
        $report = Get-CrowAssetDependencyReport -RepoRoot $fixtureRoot
        Assert-HasError `
            -Errors $report.Errors `
            -ExpectedText "Collection 'fixture' is missing required skill/module '.apm/skills/crow-case/guide.md'" `
            -Scenario 'Uses case-sensitive collection path comparisons on case-sensitive filesystems'
    }
    else {
        Write-Information `
            -MessageData 'Skipped case-sensitive path comparison scenario on a case-insensitive filesystem' `
            -InformationAction Continue
    }

    $moduleOnlyManifest = [regex]::Replace(
        $completeManifest,
        '(?m)^(      path: )\.apm/skills/crow-support\r?$',
        '$1.apm/skills/crow-support/modules/support.md')
    $supportScriptDependency = "    - git: https://github.com/bcgov/crow.git$([Environment]::NewLine)" +
        "      path: .apm/skills/crow-support/scripts/support.mjs$([Environment]::NewLine)" +
        '      ref: v0.1.0'
    Write-FixtureFile -Path $mainSkillPath -Content @'
---
name: crow-main
description: Synthetic main skill for graph tests.
---

[Main module](modules/main.md)
Use the `crow-support` skill when needed, and see
[support module][support-module].

[support-module]: ../crow-support/modules/support.md
'@
    Write-FixtureFile -Path $manifestPath -Content $moduleOnlyManifest
    $report = Get-CrowAssetDependencyReport -RepoRoot $fixtureRoot
    Assert-HasError `
        -Errors $report.Errors `
        -ExpectedText "Collection 'fixture' is missing required skill/module '.apm/skills/crow-support/scripts/support.mjs'" `
        -Scenario 'Reports a required script missing when only its linked module is bundled'

    $moduleOnlyManifest = $moduleOnlyManifest.TrimEnd() +
        [Environment]::NewLine + $supportScriptDependency
    Write-FixtureFile -Path $manifestPath -Content $moduleOnlyManifest
    $report = Get-CrowAssetDependencyReport -RepoRoot $fixtureRoot
    if ($report.Errors.Count -ne 0) {
        throw "A module-only dependency closure produced errors: $($report.Errors -join ' | ')"
    }
    $supportModuleEdge = @($report.Graph.Edges | Where-Object {
        $_.From -eq '.apm/skills/crow-main/SKILL.md' -and
        $_.To -eq '.apm/skills/crow-support/modules/support.md' -and
        $_.Kind -eq 'MarkdownLink'
    })
    if ($supportModuleEdge.Count -eq 0) {
        throw 'The dependency graph did not include the cross-skill module link.'
    }
    $supportSkillEdge = @($report.Graph.Edges | Where-Object {
        $_.From -eq '.apm/skills/crow-main/SKILL.md' -and
        $_.To -eq '.apm/skills/crow-support/SKILL.md' -and
        $_.Kind -eq 'SkillReference'
    })
    if ($supportSkillEdge.Count -ne 0) {
        throw 'The dependency graph treated an explicit module link as a requirement for the entire skill.'
    }
    Write-Information `
        -MessageData 'Passed: Accepts a module-only cross-skill dependency' `
        -InformationAction Continue

    Write-FixtureFile -Path $mainSkillPath -Content @'
---
name: crow-main
description: Synthetic main skill for graph tests.
---

Use the `crow-support` skill when needed, and see
[support module][].

[support module]: ../crow-support/modules/support.md
'@
    Write-FixtureFile -Path $manifestPath -Content $moduleOnlyManifest
    $report = Get-CrowAssetDependencyReport -RepoRoot $fixtureRoot
    if ($report.Errors.Count -ne 0) {
        throw "A collapsed-reference module-only closure produced errors: $($report.Errors -join ' | ')"
    }
    $collapsedReferenceSkillEdge = @($report.Graph.Edges | Where-Object {
        $_.From -eq '.apm/skills/crow-main/SKILL.md' -and
        $_.To -eq '.apm/skills/crow-support/SKILL.md' -and
        $_.Kind -eq 'SkillReference'
    })
    if ($collapsedReferenceSkillEdge.Count -ne 0) {
        throw 'A collapsed reference link to a module was treated as a whole-skill dependency.'
    }
    Write-Information `
        -MessageData 'Passed: Supports collapsed reference links for module-only dependencies' `
        -InformationAction Continue

    Write-FixtureFile -Path $mainSkillPath -Content @'
---
name: crow-main
description: Synthetic main skill for graph tests.
---

Use the `crow-support` skill when needed, and see
[support module].

[support module]: ../crow-support/modules/support.md
'@
    $report = Get-CrowAssetDependencyReport -RepoRoot $fixtureRoot
    if ($report.Errors.Count -ne 0) {
        throw "A shortcut-reference module-only closure produced errors: $($report.Errors -join ' | ')"
    }
    $shortcutReferenceSkillEdge = @($report.Graph.Edges | Where-Object {
        $_.From -eq '.apm/skills/crow-main/SKILL.md' -and
        $_.To -eq '.apm/skills/crow-support/SKILL.md' -and
        $_.Kind -eq 'SkillReference'
    })
    if ($shortcutReferenceSkillEdge.Count -ne 0) {
        throw 'A shortcut reference link to a module was treated as a whole-skill dependency.'
    }
    Write-Information `
        -MessageData 'Passed: Supports shortcut reference links for module-only dependencies' `
        -InformationAction Continue

    $supportReadmePath = Join-Path $fixtureRoot '.apm/skills/crow-support/README.md'
    Write-FixtureFile -Path $supportReadmePath -Content '# Support overview'
    Write-FixtureFile -Path $mainSkillPath -Content @'
---
name: crow-main
description: Synthetic main skill for graph tests.
---

Use the `crow-support` skill when needed: [support overview](../crow-support/README.md).
'@
    $supportReadmeDependency = "    - git: https://github.com/bcgov/crow.git$([Environment]::NewLine)" +
        "      path: .apm/skills/crow-support/README.md$([Environment]::NewLine)" +
        '      ref: v0.1.0'
    $nonModuleLinkManifest = $moduleOnlyManifest.TrimEnd() +
        [Environment]::NewLine + $supportReadmeDependency
    Write-FixtureFile -Path $manifestPath -Content $nonModuleLinkManifest
    $report = Get-CrowAssetDependencyReport -RepoRoot $fixtureRoot
    Assert-HasError `
        -Errors $report.Errors `
        -ExpectedText "Collection 'fixture' is missing required skill/module '.apm/skills/crow-support/SKILL.md'" `
        -Scenario 'Requires the full skill when its non-module child is linked'

    Write-FixtureFile -Path $mainSkillPath -Content @'
---
name: crow-main
description: Synthetic main skill for graph tests.
---

[Main module](modules/main.md)
Use the `crow-support` skill when needed, and see
[support module][support-module].

[support-module]: ../crow-support/modules/support.md
'@
    Write-FixtureFile -Path $manifestPath -Content $moduleOnlyManifest
    $report = Get-CrowAssetDependencyReport -RepoRoot $fixtureRoot
    if ($report.Errors.Count -ne 0) {
        throw "The restored module-only closure produced errors: $($report.Errors -join ' | ')"
    }

    Write-FixtureFile -Path $supportModulePath -Content '[`Missing module`](missing.md)'
    $report = Get-CrowAssetDependencyReport -RepoRoot $fixtureRoot
    Assert-HasError `
        -Errors $report.Errors `
        -ExpectedText "Dead local Markdown link in '.apm/skills/crow-support/modules/support.md'" `
        -Scenario 'Reports a dead Markdown link in a bundled skill module'

    Write-FixtureFile -Path $supportModulePath -Content $supportModuleContent
    Write-FixtureFile -Path $agentPath -Content @'
---
name: 'Crow Graph Test Agent'
description: 'Synthetic agent for graph tests.'
tools: ['read']
---

# Crow Graph Test Agent

## Core Principles

Load the `crow-main` skill before proceeding.
[Removed skill](../skills/crow-removed/SKILL.md)
'@
    $report = Get-CrowAssetDependencyReport -RepoRoot $fixtureRoot
    Assert-HasError `
        -Errors $report.Errors `
        -ExpectedText "Dead local Markdown link in '.apm/agents/crow-test.agent.md'" `
        -Scenario 'Reports a dead Markdown link in an agent'

    Write-FixtureFile -Path $agentPath -Content @'
---
name: 'Crow Graph Test Agent'
description: 'Synthetic agent for dependency graph tests.'
tools: ['read']
---

# Crow Graph Test Agent

## Core Principles

Load the `crow-removed-skill` skill before proceeding.
'@
    $report = Get-CrowAssetDependencyReport -RepoRoot $fixtureRoot
    Assert-HasError `
        -Errors $report.Errors `
        -ExpectedText "Unknown skill reference 'crow-removed-skill'" `
        -Scenario 'Reports an unresolved named skill reference'

    Write-FixtureFile -Path $agentPath -Content @'
---
name: 'Crow Graph Test Agent'
description: 'Synthetic agent for dependency graph tests.'
tools: ['read']
---

# Crow Graph Test Agent

## Core Principles

Load the following skill
`crow-removed-skill`
before proceeding.
'@
    $report = Get-CrowAssetDependencyReport -RepoRoot $fixtureRoot
    Assert-HasError `
        -Errors $report.Errors `
        -ExpectedText "Unknown skill reference 'crow-removed-skill'" `
        -Scenario 'Reports an unresolved skill reference split across wrapped lines'

    Write-FixtureFile -Path $agentPath -Content @'
---
name: 'Crow Graph Test Agent'
description: 'Synthetic agent for dependency graph tests.'
tools: ['read']
---

# Crow Graph Test Agent

## Core Principles

The `crow-removed-skill` skill should be loaded.
The `crow-missing-skill` skill will be used for this route.
'@
    $report = Get-CrowAssetDependencyReport -RepoRoot $fixtureRoot
    Assert-HasError `
        -Errors $report.Errors `
        -ExpectedText "Unknown skill reference 'crow-removed-skill'" `
        -Scenario 'Reports an unresolved passive skill reference'
    Assert-HasError `
        -Errors $report.Errors `
        -ExpectedText "Unknown skill reference 'crow-missing-skill'" `
        -Scenario 'Reports an unresolved future-passive skill reference'
}
finally {
    if (Test-Path -LiteralPath $fixtureRoot -PathType Container) {
        Remove-Item -LiteralPath $fixtureRoot -Recurse -Force
    }
}

exit 0
