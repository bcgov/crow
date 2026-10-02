[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$validatorPath = Join-Path $PSScriptRoot 'Test-ApiModernizationCoverage.ps1'
$powerShellPath = (Get-Process -Id $PID).Path
$utf8 = [System.Text.UTF8Encoding]::new($false)
$fixtureRoot = Join-Path ([System.IO.Path]::GetTempPath()) (
    'crow-api-modernization-coverage-' + [guid]::NewGuid().ToString('N'))
$repoRoot = Join-Path $fixtureRoot 'repository'
$inventoryPath = Join-Path $repoRoot 'docs\api-inventory.json'
$scenarioPath = Join-Path $repoRoot 'docs\testing\api-scenarios.json'
$resultsPath = Join-Path $repoRoot 'build\api-run-results.json'

function Write-TestJson {
    param(
        [string]$Path,
        [object]$Value
    )

    $parent = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    [System.IO.File]::WriteAllText(
        $Path,
        ($Value | ConvertTo-Json -Depth 30),
        $utf8)
}

function Write-TestFile {
    param(
        [string]$Path,
        [string]$Content
    )

    $parent = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    [System.IO.File]::WriteAllText($Path, $Content, $utf8)
}

function Get-ValidInventory {
    return [ordered]@{
        schemaVersion = '1.0'
        generatedAt = '2026-10-02T18:00:00Z'
        sourceRevision = '0123456789abcdef0123456789abcdef01234567'
        scope = [ordered]@{
            classification = 'SingleApp'
            serviceName = 'Test API'
            servicePath = '.'
        }
        completeness = 'Verified'
        completenessEvidence = @('EV-001', 'EV-002')
        apis = @(
            [ordered]@{
                id = 'API-001'
                name = 'Orders REST API'
                protocol = 'REST'
                version = 'v1'
                owner = 'Test team'
                consumers = @('Test client')
                authentication = 'Synthetic test identity'
                contracts = @(
                    [ordered]@{
                        type = 'OpenAPI'
                        evidenceRef = 'EV-001'
                    }
                )
                operations = @(
                    [ordered]@{
                        id = 'OP-001'
                        name = 'GetOrder'
                        confidence = 'Verified'
                        evidenceRefs = @('EV-001')
                        sideEffects = 'ReadOnly'
                        http = [ordered]@{
                            method = 'GET'
                            path = '/orders/{orderId}'
                        }
                        requestMediaTypes = @()
                        successResponses = @(
                            [ordered]@{
                                id = 'RC-001'
                                code = '200'
                                meaning = 'Order is returned.'
                            }
                        )
                        errorResponses = @(
                            [ordered]@{
                                id = 'RC-002'
                                code = '404'
                                meaning = 'Order does not exist.'
                            }
                        )
                    }
                )
            },
            [ordered]@{
                id = 'API-002'
                name = 'Orders SOAP API'
                protocol = 'SOAP'
                version = '1.1'
                owner = 'Test team'
                consumers = @('Test client')
                authentication = 'Synthetic test identity'
                contracts = @(
                    [ordered]@{
                        type = 'WSDL'
                        evidenceRef = 'EV-002'
                    }
                )
                operations = @(
                    [ordered]@{
                        id = 'OP-002'
                        name = 'CreateOrder'
                        confidence = 'Verified'
                        evidenceRefs = @('EV-002')
                        sideEffects = 'StateMutating'
                        http = [ordered]@{
                            method = 'POST'
                            path = '/Orders.svc'
                        }
                        requestMediaTypes = @('text/xml')
                        successResponses = @(
                            [ordered]@{
                                id = 'RC-003'
                                code = '200'
                                meaning = 'Order creation response is returned.'
                            }
                        )
                        errorResponses = @(
                            [ordered]@{
                                id = 'RC-004'
                                code = '500'
                                meaning = 'SOAP fault is returned.'
                            }
                        )
                        soap = [ordered]@{
                            version = '1.1'
                            action = 'urn:CreateOrder'
                            requestElement = 'CreateOrder'
                            responseElement = 'CreateOrderResponse'
                            faults = @('ValidationFault')
                        }
                    }
                )
            }
        )
        evidence = @(
            [ordered]@{
                id = 'EV-001'
                path = 'contracts\orders.openapi.yaml'
                startLine = 1
                endLine = 3
                summary = 'REST route and response contract.'
            },
            [ordered]@{
                id = 'EV-002'
                path = 'contracts\orders.wsdl'
                startLine = 1
                endLine = 3
                summary = 'SOAP operation and fault contract.'
            }
        )
        unknowns = @()
    }
}

function Get-ValidScenarioManifest {
    $revision = '0123456789abcdef0123456789abcdef01234567'
    $inventorySha256 = (Get-FileHash -LiteralPath $inventoryPath -Algorithm SHA256).Hash.ToLowerInvariant()
    return [ordered]@{
        schemaVersion = '1.1'
        inventorySourceRevision = $revision
        inventorySha256 = $inventorySha256
        targetPolicy = [ordered]@{
            environment = 'Test'
            environmentClassification = 'NonProduction'
            baselineBaseUrlEnvironmentVariable = 'LEGACY_API_BASE_URL'
            candidateBaseUrlEnvironmentVariable = 'MODERN_API_BASE_URL'
            expectedBaselineBuildId = 'legacy-orders-release-2026.09.1'
            expectedCandidateBuildId = 'modern-orders-commit-0123456789abcdef'
        }
        scenarios = @(
            [ordered]@{
                id = 'SCN-001'
                operationId = 'OP-001'
                responseCaseId = 'RC-001'
                kind = 'success'
                description = 'Existing order is returned.'
                testReference = 'tests\ApiModernizationTests.cs'
                safety = [ordered]@{
                    classification = 'ReadOnly'
                }
            },
            [ordered]@{
                id = 'SCN-002'
                operationId = 'OP-001'
                responseCaseId = 'RC-002'
                kind = 'error'
                description = 'Missing order returns the documented not-found result.'
                testReference = 'tests\ApiModernizationTests.cs'
                safety = [ordered]@{
                    classification = 'ReadOnly'
                }
            },
            [ordered]@{
                id = 'SCN-003'
                operationId = 'OP-002'
                responseCaseId = 'RC-003'
                kind = 'success'
                description = 'Isolated order is created.'
                testReference = 'tests\ApiModernizationTests.cs'
                safety = [ordered]@{
                    classification = 'IsolatedMutation'
                    approvalReference = 'docs\testing\api-scenarios-approved.md'
                    isolation = 'Dedicated synthetic test tenant.'
                    cleanup = 'Remove the unique test order after each run.'
                }
            },
            [ordered]@{
                id = 'SCN-004'
                operationId = 'OP-002'
                responseCaseId = 'RC-004'
                kind = 'error'
                description = 'Invalid isolated request returns the documented SOAP fault.'
                testReference = 'tests\ApiModernizationTests.cs'
                safety = [ordered]@{
                    classification = 'IsolatedMutation'
                    approvalReference = 'docs\testing\api-scenarios-approved.md'
                    isolation = 'Dedicated synthetic test tenant.'
                    cleanup = 'Remove any partially created test order.'
                }
            }
        )
    }
}

function Get-ValidRunResult {
    $revision = '0123456789abcdef0123456789abcdef01234567'
    $inventorySha256 = (Get-FileHash -LiteralPath $inventoryPath -Algorithm SHA256).Hash.ToLowerInvariant()
    $scenarioManifestSha256 = (Get-FileHash -LiteralPath $scenarioPath -Algorithm SHA256).Hash.ToLowerInvariant()
    $results = @()
    $manifest = Get-ValidScenarioManifest
    foreach ($scenario in $manifest.scenarios) {
        $responseClass = if ($scenario.kind -eq 'success') { 'Success' } else { 'Error' }
        $results += [ordered]@{
            scenarioId = $scenario.id
            baseline = [ordered]@{
                transport = 'HTTP'
                requestCount = 1
                outcome = 'Passed'
                responseClass = $responseClass
            }
            candidate = [ordered]@{
                transport = 'HTTP'
                requestCount = 1
                outcome = 'Passed'
                responseClass = $responseClass
            }
            comparison = [ordered]@{
                verdict = 'Equivalent'
            }
        }
    }
    return [ordered]@{
        schemaVersion = '1.1'
        generatedAt = '2026-10-02T18:30:00Z'
        inventorySourceRevision = $revision
        inventorySha256 = $inventorySha256
        scenarioManifestSha256 = $scenarioManifestSha256
        baselineBuildId = 'legacy-orders-release-2026.09.1'
        candidateBuildId = 'modern-orders-commit-0123456789abcdef'
        results = $results
    }
}

function Reset-Fixture {
    [CmdletBinding(SupportsShouldProcess)]
    param()

    if (-not $PSCmdlet.ShouldProcess($repoRoot, 'Reset API modernization test fixture')) {
        return
    }
    Write-TestJson $inventoryPath (Get-ValidInventory)
    Write-TestJson $scenarioPath (Get-ValidScenarioManifest)
    Write-TestJson $resultsPath (Get-ValidRunResult)
}

function Update-RunProvenance {
    [CmdletBinding(SupportsShouldProcess)]
    param()

    if (-not $PSCmdlet.ShouldProcess($repoRoot, 'Update API modernization test fixture provenance')) {
        return
    }
    $inventoryHash = (Get-FileHash -LiteralPath $inventoryPath -Algorithm SHA256).Hash.ToLowerInvariant()
    $manifest = [System.IO.File]::ReadAllText($scenarioPath) | ConvertFrom-Json
    $manifest.inventorySha256 = $inventoryHash
    Write-TestJson $scenarioPath $manifest

    $results = [System.IO.File]::ReadAllText($resultsPath) | ConvertFrom-Json
    $results.inventorySha256 = $inventoryHash
    $results.scenarioManifestSha256 = (
        Get-FileHash -LiteralPath $scenarioPath -Algorithm SHA256).Hash.ToLowerInvariant()
    Write-TestJson $resultsPath $results
}

function Invoke-CoverageTest {
    param(
        [string]$Name,
        [bool]$ShouldPass
    )

    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $commandOutput = @(
            & $powerShellPath -NoProfile -File $validatorPath `
                -RepoRoot $repoRoot `
                -InventoryPath 'docs\api-inventory.json' `
                -ScenarioPath 'docs\testing\api-scenarios.json' `
                -ResultsPath 'build\api-run-results.json' *>&1
        )
        $passed = $LASTEXITCODE -eq 0
    }
    finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }
    if ($passed -ne $ShouldPass) {
        throw "$Name expected pass=$ShouldPass but pass=$passed. Output: $($commandOutput -join ' | ')"
    }
    Write-Output "Passed: $Name"
}

try {
    New-Item -ItemType Directory -Path $repoRoot -Force | Out-Null
    Write-TestFile `
        (Join-Path $repoRoot 'contracts\orders.openapi.yaml') `
        ('openapi: 3.0.0' + [Environment]::NewLine + 'paths: {}')
    Write-TestFile (Join-Path $repoRoot 'contracts\orders.wsdl') '<definitions />'
    Write-TestFile (Join-Path $repoRoot 'tests\ApiModernizationTests.cs') 'namespace Tests;'
    Write-TestFile (Join-Path $repoRoot 'docs\testing\api-scenarios-approved.md') 'Approved synthetic scenario set.'

    Reset-Fixture
    Invoke-CoverageTest 'verified REST and SOAP cases pass over HTTP' $true

    Reset-Fixture
    $results = [System.IO.File]::ReadAllText($resultsPath) | ConvertFrom-Json
    $results.results[0].comparison.verdict = 'ApprovedDivergence'
    $results.results[0].comparison | Add-Member `
        -MemberType NoteProperty `
        -Name decisionReference `
        -Value 'DEC-001' `
        -Force
    Write-TestJson $resultsPath $results
    Invoke-CoverageTest 'approved divergence with decision reference passes' $true

    Reset-Fixture
    $inventory = [System.IO.File]::ReadAllText($inventoryPath) | ConvertFrom-Json
    $inventory.apis[0].operations[0].errorResponses = @()
    Write-TestJson $inventoryPath $inventory
    $scenarios = [System.IO.File]::ReadAllText($scenarioPath) | ConvertFrom-Json
    $scenarios.scenarios = @(
        $scenarios.scenarios | Where-Object { $_.responseCaseId -ne 'RC-002' })
    Write-TestJson $scenarioPath $scenarios
    $results = [System.IO.File]::ReadAllText($resultsPath) | ConvertFrom-Json
    $results.results = @($results.results | Where-Object { $_.scenarioId -ne 'SCN-002' })
    Write-TestJson $resultsPath $results
    Update-RunProvenance
    Invoke-CoverageTest 'verified success-only response contract passes' $true

    Reset-Fixture
    $inventory = [System.IO.File]::ReadAllText($inventoryPath) | ConvertFrom-Json
    $inventory.apis[0].operations[0].successResponses = @()
    Write-TestJson $inventoryPath $inventory
    Update-RunProvenance
    Invoke-CoverageTest 'operation requires at least one success response' $false

    Reset-Fixture
    $inventory = [System.IO.File]::ReadAllText($inventoryPath) | ConvertFrom-Json
    $inventory.completeness = 'Partial'
    Write-TestJson $inventoryPath $inventory
    Invoke-CoverageTest 'partial API inventory rejected' $false

    Reset-Fixture
    $inventory = [System.IO.File]::ReadAllText($inventoryPath) | ConvertFrom-Json
    $inventory.apis[0].operations[0] | Add-Member `
        -MemberType NoteProperty `
        -Name soap `
        -Value ([pscustomobject]@{
            version = '1.1'
            action = 'urn:GetOrder'
            requestElement = 'GetOrder'
            responseElement = 'GetOrderResponse'
            faults = @()
        }) `
        -Force
    Write-TestJson $inventoryPath $inventory
    Invoke-CoverageTest 'REST operation with SOAP contract rejected' $false

    Reset-Fixture
    $inventory = [System.IO.File]::ReadAllText($inventoryPath) | ConvertFrom-Json
    $inventory.apis[1].operations[0].soap.action = ''
    $inventory.apis[1].operations[0].soap.faults = @()
    Write-TestJson $inventoryPath $inventory
    Update-RunProvenance
    Invoke-CoverageTest 'empty SOAP action and fault list accepted' $true

    Reset-Fixture
    $inventory = [System.IO.File]::ReadAllText($inventoryPath) | ConvertFrom-Json
    $inventory.apis[0].operations[0].successResponses += [pscustomobject]@{
        id = 'rc-001'
        code = '206'
        meaning = 'A partial order representation is returned.'
    }
    Write-TestJson $inventoryPath $inventory
    Update-RunProvenance
    Invoke-CoverageTest 'uncovered mixed-case response ID is not hidden' $false

    Reset-Fixture
    $inventory = [System.IO.File]::ReadAllText($inventoryPath) | ConvertFrom-Json
    $inventory.apis[0].operations += [pscustomobject]@{
        id = 'op-001'
        name = 'CreateOrder'
        confidence = 'Verified'
        evidenceRefs = @('EV-001')
        sideEffects = 'StateMutating'
        http = [pscustomobject]@{
            method = 'POST'
            path = '/orders'
        }
        requestMediaTypes = @('application/json')
        successResponses = @(
            [pscustomobject]@{
                id = 'RC-005'
                code = '201'
                meaning = 'The order is created.'
            }
        )
        errorResponses = @()
    }
    Write-TestJson $inventoryPath $inventory
    $scenarios = [System.IO.File]::ReadAllText($scenarioPath) | ConvertFrom-Json
    $scenarios.scenarios += [pscustomobject]@{
        id = 'SCN-005'
        operationId = 'op-001'
        responseCaseId = 'RC-005'
        kind = 'success'
        description = 'An isolated order is created.'
        testReference = 'tests\ApiModernizationTests.cs'
        safety = [pscustomobject]@{
            classification = 'IsolatedMutation'
            approvalReference = 'docs\testing\api-scenarios-approved.md'
            isolation = 'Dedicated synthetic test tenant.'
            cleanup = 'Remove the unique test order after the run.'
        }
    }
    Write-TestJson $scenarioPath $scenarios
    Update-RunProvenance
    $results = [System.IO.File]::ReadAllText($resultsPath) | ConvertFrom-Json
    $results.results += [pscustomobject]@{
        scenarioId = 'SCN-005'
        baseline = [pscustomobject]@{
            transport = 'HTTP'
            requestCount = 1
            outcome = 'Passed'
            responseClass = 'Success'
        }
        candidate = [pscustomobject]@{
            transport = 'HTTP'
            requestCount = 1
            outcome = 'Passed'
            responseClass = 'Success'
        }
        comparison = [pscustomobject]@{
            verdict = 'Equivalent'
        }
    }
    Write-TestJson $resultsPath $results
    Invoke-CoverageTest 'mixed-case operation IDs retain their own metadata' $true

    Reset-Fixture
    $scenarios = [System.IO.File]::ReadAllText($scenarioPath) | ConvertFrom-Json
    $scenarios.inventorySourceRevision = 'fedcba9876543210fedcba9876543210fedcba98'
    Write-TestJson $scenarioPath $scenarios
    Update-RunProvenance
    Invoke-CoverageTest 'stale scenario inventory revision rejected' $false

    Reset-Fixture
    $inventory = [System.IO.File]::ReadAllText($inventoryPath) | ConvertFrom-Json
    $inventory.apis[0].name = 'Changed without refreshing the scenario manifest'
    Write-TestJson $inventoryPath $inventory
    Invoke-CoverageTest 'scenario manifest tied to exact inventory hash' $false

    Reset-Fixture
    $scenarios = [System.IO.File]::ReadAllText($scenarioPath) | ConvertFrom-Json
    $scenarios.scenarios[0].description = 'Changed after the last test run.'
    Write-TestJson $scenarioPath $scenarios
    Invoke-CoverageTest 'run results tied to exact scenario manifest hash' $false

    Reset-Fixture
    $scenarios = [System.IO.File]::ReadAllText($scenarioPath) | ConvertFrom-Json
    $scenarios.scenarios = @(
        $scenarios.scenarios | Where-Object { $_.responseCaseId -ne 'RC-004' })
    Write-TestJson $scenarioPath $scenarios
    Update-RunProvenance
    $results = [System.IO.File]::ReadAllText($resultsPath) | ConvertFrom-Json
    $results.results = @($results.results | Where-Object { $_.scenarioId -ne 'SCN-004' })
    Write-TestJson $resultsPath $results
    Invoke-CoverageTest 'every documented response case requires a scenario' $false

    Reset-Fixture
    $results = [System.IO.File]::ReadAllText($resultsPath) | ConvertFrom-Json
    $results.results = @($results.results | Where-Object { $_.scenarioId -ne 'SCN-002' })
    Write-TestJson $resultsPath $results
    Invoke-CoverageTest 'every approved scenario requires a result' $false

    Reset-Fixture
    $results = [System.IO.File]::ReadAllText($resultsPath) | ConvertFrom-Json
    $results.results[0].baseline.transport = 'InProcess'
    Write-TestJson $resultsPath $results
    Invoke-CoverageTest 'in-process result is not HTTP evidence' $false

    Reset-Fixture
    $scenarios = [System.IO.File]::ReadAllText($scenarioPath) | ConvertFrom-Json
    $scenarios.targetPolicy.environment = 'NonProduction'
    Write-TestJson $scenarioPath $scenarios
    Update-RunProvenance
    Invoke-CoverageTest 'NonProduction environment label accepted' $true

    Reset-Fixture
    $scenarios = [System.IO.File]::ReadAllText($scenarioPath) | ConvertFrom-Json
    $scenarios.targetPolicy.environment = 'PreProduction'
    Write-TestJson $scenarioPath $scenarios
    Update-RunProvenance
    Invoke-CoverageTest 'PreProduction environment label accepted' $true

    Reset-Fixture
    $scenarios = [System.IO.File]::ReadAllText($scenarioPath) | ConvertFrom-Json
    $scenarios.targetPolicy.environment = 'Production'
    $scenarios.targetPolicy.environmentClassification = 'Production'
    Write-TestJson $scenarioPath $scenarios
    Update-RunProvenance
    Invoke-CoverageTest 'production target rejected' $false

    Reset-Fixture
    $results = [System.IO.File]::ReadAllText($resultsPath) | ConvertFrom-Json
    $results.baselineBuildId = 'legacy-orders-release-2026.09.0'
    Write-TestJson $resultsPath $results
    Invoke-CoverageTest 'stale baseline build result rejected' $false

    Reset-Fixture
    $results = [System.IO.File]::ReadAllText($resultsPath) | ConvertFrom-Json
    $results.candidateBuildId = 'modern-orders-commit-fedcba9876543210'
    Write-TestJson $resultsPath $results
    Invoke-CoverageTest 'stale candidate build result rejected' $false

    Reset-Fixture
    $scenarios = [System.IO.File]::ReadAllText($scenarioPath) | ConvertFrom-Json
    $scenarios.targetPolicy.baselineBaseUrlEnvironmentVariable = 'legacyApiBaseUrl'
    Write-TestJson $scenarioPath $scenarios
    Update-RunProvenance
    Invoke-CoverageTest 'lowercase base-address environment variable rejected' $false

    Reset-Fixture
    $scenarios = [System.IO.File]::ReadAllText($scenarioPath) | ConvertFrom-Json
    $scenarios.scenarios[2].safety.cleanup = ''
    Write-TestJson $scenarioPath $scenarios
    Update-RunProvenance
    Invoke-CoverageTest 'mutating operation requires cleanup evidence' $false

    Reset-Fixture
    $results = [System.IO.File]::ReadAllText($resultsPath) | ConvertFrom-Json
    $results.results[0].comparison.verdict = 'Unresolved'
    Write-TestJson $resultsPath $results
    Invoke-CoverageTest 'unresolved comparison rejected' $false

    Reset-Fixture
    $results = [System.IO.File]::ReadAllText($resultsPath) | ConvertFrom-Json
    $results.results[1].candidate.responseClass = 'Success'
    Write-TestJson $resultsPath $results
    Invoke-CoverageTest 'error scenario must observe an error response class' $false
}
finally {
    if (Test-Path -LiteralPath $fixtureRoot) {
        Remove-Item -LiteralPath $fixtureRoot -Recurse -Force
    }
}

Write-Output 'API modernization coverage tests passed.'
exit 0
