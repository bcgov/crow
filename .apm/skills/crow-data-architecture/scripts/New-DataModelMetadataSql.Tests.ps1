[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$generatorPath = Join-Path $PSScriptRoot 'New-DataModelMetadataSql.ps1'
$powerShellPath = (Get-Process -Id $PID).Path
$utf8 = [System.Text.UTF8Encoding]::new($false)
$fixtureRoot = Join-Path ([System.IO.Path]::GetTempPath()) (
    'crow-data-metadata-' + [guid]::NewGuid().ToString('N'))

function Write-ModelFixture([string]$TableComment, [string]$ColumnComment, [string]$TableName = 'case', [string]$ColumnName = 'note', [string]$Schema = 'app', [string]$Schedule = 'Case files: retain 2 years after closure, then destroy (ARCS 100-20)', [string]$ColumnSchedule = '') {
    $document = [System.Xml.XmlDocument]::new()
    $root = $document.AppendChild($document.CreateElement('sql'))
    $root.SetAttribute('format', 'portable-v1')
    $table = $root.AppendChild($document.CreateElement('table'))
    $table.SetAttribute('name', $TableName)
    if ($Schema) { $table.SetAttribute('schema', $Schema) }
    $row = $table.AppendChild($document.CreateElement('row'))
    $row.SetAttribute('name', $ColumnName)
    $row.SetAttribute('null', '0')
    $row.SetAttribute('autoincrement', '0')
    $row.AppendChild($document.CreateElement('datatype')).InnerText = 'text'
    if ($ColumnComment) {
        if ($ColumnSchedule) { $ColumnComment += " @bcgov{RecordsSchedule=$ColumnSchedule}" }
        $row.AppendChild($document.CreateElement('comment')).InnerText = $ColumnComment
    }
    $row.AppendChild($document.CreateElement('classification')).InnerText = 'Protected B'
    $key = $table.AppendChild($document.CreateElement('key'))
    $key.SetAttribute('type', 'PRIMARY')
    $key.SetAttribute('name', 'pk')
    $key.AppendChild($document.CreateElement('part')).InnerText = $ColumnName
    if ($TableComment) { $table.AppendChild($document.CreateElement('comment')).InnerText = $TableComment }
    $table.AppendChild($document.CreateElement('records-schedule')).InnerText = $Schedule
    $path = Join-Path $fixtureRoot (([guid]::NewGuid().ToString('N')) + '.xml')
    [System.IO.File]::WriteAllText($path, $document.OuterXml, $utf8)
    return $path
}

function Invoke-Generator([string]$Name, [string]$ModelPath, [string[]]$Arguments, [int]$ExpectedExit, [string[]]$Contains, [string[]]$Excludes) {
    $previousPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $stdout = & $powerShellPath -NoProfile -File $generatorPath -Path $ModelPath @Arguments 2>$null | Out-String
        $exitCode = $LASTEXITCODE
        $all = & $powerShellPath -NoProfile -File $generatorPath -Path $ModelPath @Arguments 2>&1 | Out-String
    }
    finally {
        $ErrorActionPreference = $previousPreference
    }
    if ($exitCode -ne $ExpectedExit) { throw "$Name expected exit $ExpectedExit but got $exitCode.`n$all" }
    $normalizedAll = [regex]::Replace($all, '\s+', ' ')
    $normalizedStdout = [regex]::Replace($stdout, '\s+', ' ')
    foreach ($text in $Contains) {
        $normalizedText = [regex]::Replace($text, '\s+', ' ')
        if (-not $normalizedAll.Contains($normalizedText)) { throw "$Name expected output containing:`n$text`n--- actual ---`n$all" }
    }
    foreach ($text in $Excludes) {
        $normalizedText = [regex]::Replace($text, '\s+', ' ')
        if ($normalizedStdout.Contains($normalizedText)) { throw "$Name expected stdout without:`n$text`n--- actual ---`n$stdout" }
    }
    Write-Host "Passed: $Name"
    return $stdout
}

New-Item -ItemType Directory -Path $fixtureRoot | Out-Null
try {
    $quoted = Write-ModelFixture "Owner's cases" "It's a note"

    Invoke-Generator 'SQL Server escapes quotes and updates existing properties' $quoted @('-Dialect', 'SqlServer') 0 @(
        "@value = N'Owner''s cases'",
        "IF EXISTS (SELECT 1 FROM sys.fn_listextendedproperty(N'RecordsSchedule', N'SCHEMA', N'app', N'TABLE', N'case', NULL, NULL))",
        "@name = N'DataClassification', @value = N'Protected B'",
        "@level2type = N'COLUMN', @level2name = N'note'") @('ADD SENSITIVITY') | Out-Null
    Invoke-Generator 'SQL Server sensitivity classification is opt-in' $quoted @('-Dialect', 'SqlServer', '-IncludeSensitivityClassification') 0 @(
        "ADD SENSITIVITY CLASSIFICATION TO [app].[case].[note] WITH (LABEL = N'Protected B', RANK = MEDIUM);") @() | Out-Null
    Invoke-Generator 'PostgreSQL writes encoded trailers' $quoted @('-Dialect', 'PostgreSql') 0 @(
        "COMMENT ON TABLE ""app"".""case"" IS 'Owner''s cases @bcgov{RecordsSchedule=Case files: retain 2 years after closure, then destroy (ARCS 100-20)}';",
        "COMMENT ON COLUMN ""app"".""case"".""note"" IS 'It''s a note @bcgov{DataClassification=Protected B}';") @() | Out-Null
    $columnSchedule = Write-ModelFixture 'Cases' 'Identity detail' -ColumnSchedule 'Identity details: retain 2 years after the decision is final, then destroy (ORCS 12345-20)'
    Invoke-Generator 'SQL Server stores column-specific schedules as extended properties' $columnSchedule @('-Dialect', 'SqlServer') 0 @(
        "@name = N'RecordsSchedule', @value = N'Identity details: retain 2 years after the decision is final, then destroy (ORCS 12345-20)'",
        "@level2type = N'COLUMN', @level2name = N'note'") @() | Out-Null
    $noColumnSchedule = Write-ModelFixture 'Cases' 'Identity detail'
    Invoke-Generator 'SQL Server removes column schedule overrides absent from the model' $noColumnSchedule @('-Dialect', 'SqlServer') 0 @(
        "IF EXISTS (SELECT 1 FROM sys.fn_listextendedproperty(N'RecordsSchedule', N'SCHEMA', N'app', N'TABLE', N'case', N'COLUMN', N'note'))",
        "EXEC sys.sp_dropextendedproperty @name = N'RecordsSchedule', @level0type = N'SCHEMA', @level0name = N'app'") @() | Out-Null
    Invoke-Generator 'Oracle annotations store column-specific schedules' $columnSchedule @('-Dialect', 'OracleAnnotations') 0 @(
        "ANNOTATIONS (ADD ""RecordsSchedule"" 'Identity details: retain 2 years after the decision is final, then destroy (ORCS 12345-20)')") @() | Out-Null
    Invoke-Generator 'Oracle stores column schedules in the comment trailer' $columnSchedule @('-Dialect', 'Oracle') 0 @(
        "COMMENT ON COLUMN ""app"".""case"".""note"" IS 'Identity detail @bcgov{DataClassification=Protected B;RecordsSchedule=Identity details: retain 2 years after the decision is final, then destroy (ORCS 12345-20)}';") @() | Out-Null
    Invoke-Generator 'PostgreSQL stores column schedules in the comment trailer' $columnSchedule @('-Dialect', 'PostgreSql') 0 @(
        "COMMENT ON COLUMN ""app"".""case"".""note"" IS 'Identity detail @bcgov{DataClassification=Protected B;RecordsSchedule=Identity details: retain 2 years after the decision is final, then destroy (ORCS 12345-20)}';") @() | Out-Null
    Invoke-Generator 'MySQL stores column schedules in the comment trailer' $columnSchedule @('-Dialect', 'MySql') 0 @(
        "--   COMMENT 'Identity detail @bcgov{DataClassification=Protected B;RecordsSchedule=Identity details: retain 2 years after the decision is final, then destroy (ORCS 12345-20)}'") @() | Out-Null
    Invoke-Generator 'PostgreSQL can omit schema' $quoted @('-Dialect', 'PostgreSql', '-OmitSchema') 0 @(
        'COMMENT ON TABLE "case" IS') @('"app"') | Out-Null
    Invoke-Generator 'Oracle preserves model identifier spelling by default' $quoted @('-Dialect', 'Oracle') 0 @(
        "COMMENT ON TABLE ""app"".""case"" IS 'Owner''s cases @bcgov{RecordsSchedule=Case files: retain 2 years after closure, then destroy (ARCS 100-20)}';") @() | Out-Null
    Invoke-Generator 'Oracle folds unquoted identifiers only when requested' $quoted @('-Dialect', 'Oracle', '-FoldUnquotedIdentifiers') 0 @(
        "COMMENT ON TABLE ""APP"".""CASE"" IS 'Owner''s cases @bcgov{RecordsSchedule=Case files: retain 2 years after closure, then destroy (ARCS 100-20)}';") @() | Out-Null
    Invoke-Generator 'Oracle annotations replace values re-runnably' $quoted @('-Dialect', 'OracleAnnotations') 0 @(
        "COMMENT ON TABLE ""app"".""case"" IS 'Owner''s cases';",
        'ALTER TABLE "app"."case" ANNOTATIONS (DROP IF EXISTS "RecordsSchedule");',
        "ALTER TABLE ""app"".""case"" ANNOTATIONS (ADD ""RecordsSchedule"" 'Case files: retain 2 years after closure, then destroy (ARCS 100-20)');",
        'ALTER TABLE "app"."case" MODIFY ("note" ANNOTATIONS (DROP IF EXISTS "RecordsSchedule"));',
        "ALTER TABLE ""app"".""case"" MODIFY (""note"" ANNOTATIONS (ADD ""DataClassification"" 'Protected B'));") @('@bcgov{') | Out-Null
    Invoke-Generator 'Oracle removes a column schedule override when returning to the table schedule' $noColumnSchedule @('-Dialect', 'OracleAnnotations') 0 @(
        'ALTER TABLE "app"."case" MODIFY ("note" ANNOTATIONS (DROP IF EXISTS "RecordsSchedule"));') @() | Out-Null
    Invoke-Generator 'Oracle keeps mixed identifiers quoted as written' (Write-ModelFixture 'x' 'y' 'Case Table' 'Note') @('-Dialect', 'Oracle') 0 @(
        'COMMENT ON TABLE "app"."Case Table" IS', 'COMMENT ON COLUMN "app"."Case Table"."Note" IS') @() | Out-Null

    $backslash = Write-ModelFixture 'Path C:\temp' "Line one`nLine two"
    Invoke-Generator 'MySQL escapes backslashes and keeps column notes on one line' $backslash @('-Dialect', 'MySql') 0 @(
        "ALTER TABLE ``app``.``case`` COMMENT = 'Path C:\\temp @bcgov{RecordsSchedule=Case files: retain 2 years after closure, then destroy (ARCS 100-20)}';",
        "--   COMMENT 'Line one\nLine two @bcgov{DataClassification=Protected B}'") @('ALTER TABLE `app`.`case` MODIFY') | Out-Null

    $injection = Write-ModelFixture 'x' 'y' "evil&#10;DROP TABLE t;" 'note'
    $injectionXml = [System.IO.File]::ReadAllText($injection).Replace('evil&amp;#10;DROP', 'evil&#10;DROP')
    [System.IO.File]::WriteAllText($injection, $injectionXml, $utf8)
    Invoke-Generator 'control characters in names are rejected' $injection @('-Dialect', 'MySql') 1 @(
        'contains control characters', 'no SQL generated') @('DROP TABLE t;') | Out-Null

    $long = Write-ModelFixture 'x' ('a' * 1100)
    Invoke-Generator 'MySQL column comment limit fails' $long @('-Dialect', 'MySql') 1 @('allows 1024') @('COMMENT') | Out-Null
    Invoke-Generator 'PostgreSQL has no comment limit' $long @('-Dialect', 'PostgreSql') 0 @('aaaa') @() | Out-Null
    Invoke-Generator 'Oracle comment byte limit fails' (Write-ModelFixture 'x' ([string][char]0x00E9 * 2100)) @('-Dialect', 'Oracle') 1 @('allows 4000') @() | Out-Null
    Invoke-Generator 'SQL Server property byte limit fails' (Write-ModelFixture 'x' ('b' * 3800)) @('-Dialect', 'SqlServer') 1 @('allows 7500') @() | Out-Null

    $noSchema = Write-ModelFixture 'x' 'y' 'case' 'note' ''
    Invoke-Generator 'missing schema fails outside SQL Server' $noSchema @('-Dialect', 'PostgreSql') 1 @("has no schema; 'dbo' is a SQL Server default", 'no SQL written') @('COMMENT ON') | Out-Null
    Invoke-Generator 'missing schema uses dbo for SQL Server' $noSchema @('-Dialect', 'SqlServer') 0 @("@level0name = N'dbo'") @() | Out-Null

    Invoke-Generator 'missing column description fails governance' (Write-ModelFixture 'x' '') @('-Dialect', 'PostgreSql') 1 @('requires a non-empty comment', 'no SQL generated') @('COMMENT ON') | Out-Null
    Invoke-Generator 'missing table description fails governance' (Write-ModelFixture '' 'y') @('-Dialect', 'SqlServer') 1 @('requires a non-empty comment', 'no SQL generated') @('sp_addextendedproperty') | Out-Null
    Invoke-Generator 'missing records schedule fails governance' (Write-ModelFixture 'x' 'y' -Schedule '') @('-Dialect', 'Oracle') 1 @('requires a non-empty records-schedule') @('COMMENT ON') | Out-Null
    Invoke-Generator 'non-schedule trailer in description fails' (Write-ModelFixture 'x' 'see @bcgov{DataClassification=Public}') @('-Dialect', 'PostgreSql') 1 @('terminal @bcgov{RecordsSchedule=...} trailer') @('COMMENT ON') | Out-Null

    Invoke-Generator 'trailer percent-encodes every reserved character' (Write-ModelFixture 'x' 'y' -Schedule 'Case files 100% {x=y}; logs: retain 2 years after closure (ARCS 100-20)') @('-Dialect', 'PostgreSql') 0 @(
        '@bcgov{RecordsSchedule=Case files 100%25 %7Bx%3Dy%7D%3B logs: retain 2 years after closure (ARCS 100-20)}') @() | Out-Null
    Invoke-Generator 'PostgreSQL preserves model identifier spelling by default' (Write-ModelFixture 'x' 'y' 'CaseFile' 'NoteText' 'App') @('-Dialect', 'PostgreSql') 0 @(
        'COMMENT ON TABLE "App"."CaseFile" IS', 'COMMENT ON COLUMN "App"."CaseFile"."NoteText" IS') @() | Out-Null
    Invoke-Generator 'PostgreSQL folds unquoted identifiers only when requested' (Write-ModelFixture 'x' 'y' 'CaseFile' 'NoteText' 'App') @('-Dialect', 'PostgreSql', '-FoldUnquotedIdentifiers') 0 @(
        'COMMENT ON TABLE "app"."casefile" IS', 'COMMENT ON COLUMN "app"."casefile"."notetext" IS') @() | Out-Null
    Invoke-Generator 'PostgreSQL keeps and escapes quoted identifiers' (Write-ModelFixture 'x' 'y' 'Case "A"' 'note') @('-Dialect', 'PostgreSql') 0 @(
        'COMMENT ON TABLE "app"."Case ""A""" IS') @() | Out-Null
    Invoke-Generator 'SQL Server escapes closing brackets' (Write-ModelFixture 'x' 'y' 'a]b' 'note') @('-Dialect', 'SqlServer', '-IncludeSensitivityClassification') 0 @(
        'ADD SENSITIVITY CLASSIFICATION TO [app].[a]]b].[note]') @() | Out-Null
    Invoke-Generator 'MySQL escapes backticks' (Write-ModelFixture 'x' 'y' 'a`b' 'note') @('-Dialect', 'MySql') 0 @(
        'ALTER TABLE `app`.`a``b` COMMENT') @() | Out-Null
    Invoke-Generator 'Oracle rejects double quotes in identifiers' (Write-ModelFixture 'x' 'y' 'a"b' 'note') @('-Dialect', 'Oracle') 1 @(
        'Oracle identifiers cannot contain double quotes', 'no SQL written') @('COMMENT ON') | Out-Null
    Invoke-Generator 'Oracle keeps ampersands literal' (Write-ModelFixture 'R&D cases' 'y') @('-Dialect', 'Oracle') 0 @(
        'SET DEFINE OFF', "IS 'R&D cases @bcgov{") @() | Out-Null

    $cafe = 'Caf' + [char]0x00E9
    $resume = 'R' + [char]0x00E9 + 'sum' + [char]0x00E9
    $encodingModel = Write-ModelFixture "$cafe files" "$resume details" $cafe $resume 'App'
    $encodingModelText = [System.IO.File]::ReadAllText($encodingModel, $utf8)
    [System.IO.File]::WriteAllText(
        $encodingModel,
        '<?xml version="1.0" encoding="iso-8859-1"?>' + $encodingModelText,
        $utf8)
    $expectedUnicodeTable = "COMMENT ON TABLE ""App"".""$cafe"" IS '$cafe files"
    $expectedUnicodeColumn = "COMMENT ON COLUMN ""App"".""$cafe"".""$resume"" IS '$resume details"
    Invoke-Generator 'UTF-8 text overrides a conflicting XML encoding declaration' $encodingModel @('-Dialect', 'PostgreSql') 0 @(
        $expectedUnicodeTable, $expectedUnicodeColumn) @() | Out-Null

    Invoke-Generator 'PostgreSQL identifier byte limit fails' (Write-ModelFixture 'x' 'y' ('t' * 64)) @('-Dialect', 'PostgreSql') 1 @('64 bytes; PostgreSql allows 63') @() | Out-Null
    Invoke-Generator 'MySQL identifier limit fails' (Write-ModelFixture 'x' 'y' ('t' * 65)) @('-Dialect', 'MySql') 1 @('65 characters; MySql allows 64') @() | Out-Null
    Invoke-Generator 'Oracle identifier byte limit fails' (Write-ModelFixture 'x' 'y' ([string][char]0x00E9 * 65)) @('-Dialect', 'Oracle') 1 @('130 bytes; Oracle allows 128') @() | Out-Null
    Invoke-Generator 'Oracle annotation value limit fails' (Write-ModelFixture 'x' 'y' -Schedule (('s' * 3957) + ': retain 2 years after closure (ARCS 100-20)')) @('-Dialect', 'OracleAnnotations') 1 @('annotation metadata is 4001 characters') @() | Out-Null

    Invoke-Generator 'sensitivity option requires SQL Server' $quoted @('-Dialect', 'PostgreSql', '-IncludeSensitivityClassification') 1 @('applies only to') @() | Out-Null
    Invoke-Generator 'omit schema is rejected for SQL Server' $quoted @('-Dialect', 'SqlServer', '-OmitSchema') 1 @('not supported for SqlServer') @() | Out-Null
    Invoke-Generator 'identifier folding option is limited to Oracle and PostgreSQL' $quoted @('-Dialect', 'SqlServer', '-FoldUnquotedIdentifiers') 1 @('applies only to Oracle and PostgreSql') @() | Out-Null

    $invalid = Write-ModelFixture 'x' 'y'
    [System.IO.File]::WriteAllText($invalid, [System.IO.File]::ReadAllText($invalid).Replace('Protected B', 'Secret'), $utf8)
    Invoke-Generator 'invalid model generates nothing' $invalid @('-Dialect', 'PostgreSql') 1 @('classification must be exactly one of', 'no SQL generated') @('COMMENT ON') | Out-Null
    Invoke-Generator 'missing model exits 2' (Join-Path $fixtureRoot 'missing.xml') @('-Dialect', 'PostgreSql') 2 @('not found') @() | Out-Null

    $outFile = Join-Path $fixtureRoot 'out.sql'
    Invoke-Generator 'out file receives SQL' $quoted @('-Dialect', 'PostgreSql', '-OutFile', $outFile) 0 @() @('COMMENT ON') | Out-Null
    if (-not ([System.IO.File]::ReadAllText($outFile)).Contains('COMMENT ON TABLE "app"."case"')) { throw 'out file did not receive SQL.' }
    Write-Host 'Passed: out file content'

    Push-Location -LiteralPath $fixtureRoot
    try {
        Invoke-Generator 'relative out file resolves from the current location' $quoted @('-Dialect', 'PostgreSql', '-OutFile', 'relative.sql') 0 @() @('COMMENT ON') | Out-Null
    }
    finally {
        Pop-Location
    }
    if (-not (Test-Path -LiteralPath (Join-Path $fixtureRoot 'relative.sql') -PathType Leaf)) { throw 'relative out file was not written.' }
    Write-Host 'Passed: relative out file content'
}
finally {
    if (Test-Path -LiteralPath $fixtureRoot) {
        Remove-Item -LiteralPath $fixtureRoot -Recurse -Force
    }
}

Write-Host 'All data architecture metadata SQL tests passed.'
exit 0
