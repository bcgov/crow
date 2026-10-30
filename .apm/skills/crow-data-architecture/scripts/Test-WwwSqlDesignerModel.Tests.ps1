[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$validatorPath = Join-Path $PSScriptRoot 'Test-WwwSqlDesignerModel.ps1'
$examplePath = Join-Path (Split-Path $PSScriptRoot -Parent) 'resources/example-permit-model.xml'
$powerShellPath = (Get-Process -Id $PID).Path
$utf8 = [System.Text.UTF8Encoding]::new($false)
$fixtureRoot = Join-Path ([System.IO.Path]::GetTempPath()) (
    'crow-data-architecture-' + [guid]::NewGuid().ToString('N'))
$example = [System.IO.File]::ReadAllText($examplePath, $utf8)

function Invoke-ModelTest {
    param(
        [string]$Name,
        [string]$Content,
        [int]$ExpectedExit,
        [string]$ExpectedText,
        [switch]$Governance,
        [byte[]]$Bytes
    )

    $path = Join-Path $fixtureRoot (([guid]::NewGuid().ToString('N')) + '.xml')
    if ($Bytes) { [System.IO.File]::WriteAllBytes($path, $Bytes) }
    else { [System.IO.File]::WriteAllText($path, $Content, $utf8) }
    $arguments = @('-NoProfile', '-File', $validatorPath, '-Path', $path)
    if ($Governance) { $arguments += '-RequireGovernanceMetadata' }

    $previousPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $output = (& $powerShellPath @arguments 2>&1 | Out-String)
        $exitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previousPreference
    }
    if ($exitCode -ne $ExpectedExit) {
        throw "$Name expected exit $ExpectedExit but got $exitCode.`n$output"
    }
    $normalizedOutput = [regex]::Replace($output, '\s+', ' ')
    $normalizedExpectedText = [regex]::Replace($ExpectedText, '\s+', ' ')
    if ($ExpectedText -and -not $normalizedOutput.Contains($normalizedExpectedText)) {
        throw "$Name expected output containing '$ExpectedText'.`n$output"
    }
    Write-Host "Passed: $Name"
}

function Edit-Example([string]$Find, [string]$Replace) {
    if (-not $example.Contains($Find)) { throw "Fixture text not found: $Find" }
    return $example.Replace($Find, $Replace)
}

New-Item -ItemType Directory -Path $fixtureRoot | Out-Null
try {
    Invoke-ModelTest 'example passes with governance metadata' $example 0 'Model validation passed: 2 table(s)' -Governance
    $columnScheduleModel = Edit-Example '<comment>Requested permit type.</comment>' '<comment>Requested permit type. @bcgov{RecordsSchedule=Applicant identity data: retain 2 years after closure, then destroy (ORCS 12345-20)}</comment>'
    Invoke-ModelTest 'column-specific schedule trailer passes' $columnScheduleModel 0 'Model validation passed' -Governance
    $invalidColumnScheduleModel = Edit-Example '<comment>Requested permit type.</comment>' '<comment>Requested permit type. @bcgov{RecordsSchedule=ORCS 12345-20}</comment>'
    Invoke-ModelTest 'malformed column schedule trailer fails' $invalidColumnScheduleModel 1 'must read as'
    $trailerOnlyColumnComment = Edit-Example '<comment>Requested permit type.</comment>' '<comment>@bcgov{RecordsSchedule=Applicant identity data: retain 2 years after closure, then destroy (ORCS 12345-20)}</comment>'
    Invoke-ModelTest 'column schedule trailer requires a description' $trailerOnlyColumnComment 1 'requires a human-readable column description'
    Invoke-ModelTest 'empty file fails' '' 1 'Invalid XML'

    Invoke-ModelTest 'wrong format attribute fails' (Edit-Example 'format="portable-v1"' 'format="legacy"') 1 'format="portable-v1"'
    Invoke-ModelTest 'DOCTYPE is rejected' (Edit-Example '<sql format' '<!DOCTYPE sql><sql format') 1 'DTD and entity'
    Invoke-ModelTest 'invalid UTF-8 is rejected' '' 1 'not valid UTF-8' -Bytes ([byte[]](0x3C, 0x73, 0xFF, 0x3E))
    Invoke-ModelTest 'unknown element fails' (Edit-Example '<comment>Requested permit type.</comment>' '<comment>Requested permit type.</comment><note>x</note>') 1 "Unknown element 'note'"
    Invoke-ModelTest 'uppercase element fails' (Edit-Example '<comment>Requested permit type.</comment>' '<COMMENT>Requested permit type.</COMMENT>') 1 "Element 'COMMENT' must be lowercase"
    Invoke-ModelTest 'group outside datatypes fails' (Edit-Example '<comment>Requested permit type.</comment>' '<comment>Requested permit type.</comment><group/>') 1 "Unknown element 'group'"
    Invoke-ModelTest 'datatypes registry is ignored' (Edit-Example '<table x="40"' '<datatypes db="portable"><group label="Numeric"><type label="Integer" sql="integer"/></group></datatypes><table x="40"') 0 'Model validation passed'
    Invoke-ModelTest 'misplaced classification fails' (Edit-Example '<comment>Controlled list' '<classification>Public</classification><comment>Controlled list') 1 "Misplaced element 'classification'"
    Invoke-ModelTest 'duplicate row comment fails' (Edit-Example '<comment>Requested permit type.</comment>' '<comment>Requested permit type.</comment><comment>Again</comment>') 1 "Duplicate 'comment'"
    Invoke-ModelTest 'invalid classification fails' (Edit-Example '<classification>Protected B</classification>' '<classification>Confidential</classification>') 1 'classification must be exactly one of'
    Invoke-ModelTest 'classification is case-sensitive' (Edit-Example '<classification>Protected B</classification>' '<classification>protected b</classification>') 1 'classification must be exactly one of'
    Invoke-ModelTest 'unknown datatype fails' (Edit-Example '<datatype>decimal(12,2)</datatype>' '<datatype>money</datatype>') 1 "datatype 'money'"
    Invoke-ModelTest 'uppercase datatype fails' (Edit-Example '<datatype>decimal(12,2)</datatype>' '<datatype>DECIMAL(12,2)</datatype>') 1 'lowercase portable-v1 token'
    Invoke-ModelTest 'decimal scale above precision fails' (Edit-Example '<datatype>decimal(12,2)</datatype>' '<datatype>decimal(2,4)</datatype>') 1 'scale <= precision'
    Invoke-ModelTest 'string max is accepted' (Edit-Example '<datatype>string(200)</datatype>' '<datatype>string(max)</datatype>') 0 'Model validation passed'
    Invoke-ModelTest 'string zero length fails' (Edit-Example '<datatype>string(200)</datatype>' '<datatype>string(0)</datatype>') 1 'positive integer'
    Invoke-ModelTest 'facets on date fail' (Edit-Example '<datatype>date</datatype>' '<datatype>date(3)</datatype>') 1 'does not accept facets'
    Invoke-ModelTest 'autoincrement on string fails' (Edit-Example 'name="application_number" null="0" autoincrement="0"' 'name="application_number" null="0" autoincrement="1"') 1 'autoincrement requires the integer type'
    Invoke-ModelTest 'invalid null flag fails' (Edit-Example 'name="applicant_name" null="0"' 'name="applicant_name" null="yes"') 1 "null must be '0' or '1'"
    Invoke-ModelTest 'duplicate table identity fails' (Edit-Example 'name="permit_application" schema="permit"' 'name=" PERMIT_TYPE " schema="Permit"') 1 'Duplicate table identity'
    Invoke-ModelTest 'case-only duplicate rows warn' (Edit-Example '<row name="description"' '<row name="Description" null="0" autoincrement="0"><datatype>text</datatype><comment>x</comment><classification>Public</classification></row><row name="description"') 0 'differ only by case'
    Invoke-ModelTest 'two primary keys fail' (Edit-Example '<key type="UNIQUE" name="uq_permit_application_number">' '<key type="PRIMARY" name="uq_permit_application_number">') 1 'more than one PRIMARY key'
    Invoke-ModelTest 'unknown key type fails' (Edit-Example '<key type="INDEX"' '<key type="SPATIAL"') 1 "key type 'SPATIAL'"
    Invoke-ModelTest 'missing key part row fails' (Edit-Example '<part>application_number</part>' '<part>missing_column</part>') 1 "key part row 'missing_column' not found"
    Invoke-ModelTest 'key part names are case-sensitive' (Edit-Example '<part>application_number</part>' '<part>Application_Number</part>') 1 'not found'
    Invoke-ModelTest 'missing relation table fails' (Edit-Example 'relation table="permit_type"' 'relation table="missing_table"') 1 'relation target table [permit].[missing_table] not found'
    Invoke-ModelTest 'relation table lookup is case-insensitive' (Edit-Example 'relation table="permit_type" schema="permit"' 'relation table="PERMIT_TYPE" schema="Permit"') 0 'Model validation passed'
    Invoke-ModelTest 'missing relation row fails' (Edit-Example 'row="permit_type_code" name=' 'row="missing_column" name=') 1 'relation target row'
    Invoke-ModelTest 'relation to non-key warns' (Edit-Example 'row="permit_type_code" name=' 'row="description" name=') 0 'not a single-column PRIMARY or UNIQUE key'
    Invoke-ModelTest 'relation type mismatch warns' (Edit-Example '<datatype>string(20)</datatype>
      <relation' '<datatype>string(25)</datatype>
      <relation') 0 'differs from relation target datatype'
    Invoke-ModelTest 'missing classification passes without governance' (Edit-Example '<classification>Protected B</classification>' '') 0 'Model validation passed'
    Invoke-ModelTest 'missing classification fails with governance' (Edit-Example '<classification>Protected B</classification>' '') 1 'requires a classification' -Governance
    Invoke-ModelTest 'missing records schedule fails with governance' (Edit-Example '<records-schedule>Permit type reference list: retain until the list is superseded, then destroy (ORCS 99999-01, placeholder; confirm with the records officer)</records-schedule>' '') 1 'non-empty records-schedule' -Governance
    Invoke-ModelTest 'misspelled row attribute fails' (Edit-Example 'name="applicant_name" null="0"' 'name="applicant_name" nul="0" null="0"') 1 "Unknown attribute 'nul' on 'row'"
    Invoke-ModelTest 'unknown table attribute fails' (Edit-Example 'name="permit_application" schema="permit"' 'name="permit_application" schema="permit" owner="x"') 1 "Unknown attribute 'owner' on 'table'"
    Invoke-ModelTest 'unknown root attribute fails' (Edit-Example 'format="portable-v1"' 'format="portable-v1" version="2"') 1 "Unknown attribute 'version' on 'sql'"
    Invoke-ModelTest 'missing null flag warns' (Edit-Example 'name="applicant_name" null="0"' 'name="applicant_name"') 0 "null attribute is missing; the designer treats it as '0'"
    Invoke-ModelTest 'non-schedule trailer fails' (Edit-Example '<comment>Requested permit type.</comment>' '<comment>Requested @bcgov{x=1} type.</comment>') 1 'terminal @bcgov{RecordsSchedule=...} trailer'
    Invoke-ModelTest 'CDATA comment is accepted' (Edit-Example '<comment>Requested permit type.</comment>' '<comment><![CDATA[Requested <permit> type.]]></comment>') 0 'Model validation passed'
    Invoke-ModelTest 'oversized string length fails without overflow' (Edit-Example '<datatype>string(200)</datatype>' '<datatype>string(99999999999999999999999)</datatype>') 1 'positive integer'
    Invoke-ModelTest 'oversized decimal precision fails without overflow' (Edit-Example '<datatype>decimal(12,2)</datatype>' '<datatype>decimal(99999999999999999999999,2)</datatype>') 1 'precision <= 1000'
    Invoke-ModelTest 'oversized decimal scale fails without overflow' (Edit-Example '<datatype>decimal(12,2)</datatype>' '<datatype>decimal(12,99999999999999999999999)</datatype>') 1 'scale <= precision'
    Invoke-ModelTest 'nested markup in comment fails' (Edit-Example '<comment>Requested permit type.</comment>' '<comment>Requested <b/> type.</comment>') 1 'exactly one text node'
    Invoke-ModelTest 'control characters in row names fail' (Edit-Example 'name="applicant_name"' 'name="applicant&#10;name"') 1 'contains control characters'
    $schedule = 'Permit type reference list: retain until the list is superseded, then destroy (ORCS 99999-01, placeholder; confirm with the records officer)'
    $scheduleCases = @(
        @('code-only records schedule fails', 'ORCS 12345-20', 1, 'must read as'),
        @('records schedule without bracketed number fails', 'Permit files: retain 7 years after closure', 1, 'must read as'),
        @('disposition code in schedule text fails', 'Permit files: retain 7 years after closure, then DE (ORCS 12345-20)', 1, "spell out 'DE'"),
        @('schedule number outside brackets fails', 'ORCS 12345-20 permit files: retain 7 years after closure (ORCS 12345-20)', 1, "spell out 'ORCS'"),
        @('schedule without retention period fails', 'Permit files: retain after closure (ORCS 12345-20)', 1, 'retention period in words'),
        @('schedule without trigger event fails', 'Permit files: retain 7 years, then destroy (ORCS 12345-20)', 1, 'event that starts'),
        @('permanent schedule passes', 'Permit register: retain permanently and transfer to the Digital Archives (ARCS 100-20)', 0, 'Model validation passed'),
        @('spelled-out fiscal period passes', 'Permit files: keep seven fiscal years following closure (ORCS 12345-20)', 0, 'Model validation passed'))
    foreach ($case in $scheduleCases) {
        Invoke-ModelTest $case[0] (Edit-Example "<records-schedule>$schedule</records-schedule>" "<records-schedule>$($case[1])</records-schedule>") $case[2] $case[3]
    }
    Invoke-ModelTest 'no tables fails' '<?xml version="1.0" encoding="utf-8" ?><sql format="portable-v1"></sql>' 1 'no tables'
}
finally {
    if (Test-Path -LiteralPath $fixtureRoot) {
        Remove-Item -LiteralPath $fixtureRoot -Recurse -Force
    }
}

$previousPreference = $ErrorActionPreference
$ErrorActionPreference = 'Continue'
try {
    $output = (& $powerShellPath -NoProfile -File $validatorPath -Path (Join-Path $fixtureRoot 'missing.xml') 2>&1 | Out-String)
    $exitCode = $LASTEXITCODE
}
finally {
    $ErrorActionPreference = $previousPreference
}
if ($exitCode -ne 2) { throw "missing file expected exit 2 but got $exitCode.`n$output" }
Write-Host 'Passed: missing file exits 2'
Write-Host 'All data architecture model validation tests passed.'
exit 0
