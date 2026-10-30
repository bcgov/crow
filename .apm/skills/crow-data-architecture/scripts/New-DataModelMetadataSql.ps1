<#
.SYNOPSIS
  Generates database-resident metadata SQL from a WWW SQL Designer portable-v1 model.

.DESCRIPTION
  Validates the model with Test-WwwSqlDesignerModel.ps1, then emits re-runnable
  statements that store table and column descriptions, table- or
  column-level records schedules, and B.C. information security
  classifications in the target database. Names match the bcgov/wwwsqldesigner
  exports: MS_Description, RecordsSchedule, and DataClassification.

  SqlServer          Extended properties; optional ADD SENSITIVITY CLASSIFICATION (2019+).
  OracleAnnotations  COMMENT ON for descriptions plus schema annotations (23ai+, 19.28+).
  Oracle             COMMENT ON with a parseable @bcgov{...} trailer.
  PostgreSql         COMMENT ON with a parseable @bcgov{...} trailer.
  MySql              ALTER TABLE ... COMMENT with a trailer. Column comments require
                     the full column definition, so they are emitted as review notes.
  -FoldUnquotedIdentifiers matches the folding used by unquoted Oracle/PostgreSQL DDL.

  The script never connects to a database. Review the output before applying it.
  It validates with -RequireGovernanceMetadata, so every run sets every description,
  records schedule, and classification.   It removes a column-level RecordsSchedule override when that column has no
  such trailer in the model. It does not remove metadata for objects missing
  from the model; drop those objects through reviewed migrations.
  Exit codes: 0 generated, 1 validation or limit error, 2 model file not found.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$Path,

    [Parameter(Mandatory)]
    [ValidateSet('SqlServer', 'PostgreSql', 'Oracle', 'OracleAnnotations', 'MySql')]
    [string]$Dialect,

    [switch]$IncludeSensitivityClassification,

    [switch]$OmitSchema,

    [switch]$FoldUnquotedIdentifiers,

    [string]$OutFile
)

$ErrorActionPreference = 'Stop'
$validatorPath = Join-Path $PSScriptRoot 'Test-WwwSqlDesignerModel.ps1'
$defaultSchema = 'dbo'
$descriptionName = 'MS_Description'
$scheduleName = 'RecordsSchedule'
$classificationName = 'DataClassification'
$sensitivityRanks = @{
    'Public'      = 'NONE'
    'Protected A' = 'LOW'
    'Protected B' = 'MEDIUM'
    'Protected C' = 'HIGH'
}
$script:errors = [System.Collections.Generic.List[string]]::new()

function Exit-Generation([string]$Message, [int]$Code) {
    [Console]::Error.WriteLine("ERROR: $Message")
    exit $Code
}

if ($IncludeSensitivityClassification -and $Dialect -ne 'SqlServer') {
    Exit-Generation '-IncludeSensitivityClassification applies only to -Dialect SqlServer.' 1
}
if ($OmitSchema -and $Dialect -eq 'SqlServer') {
    Exit-Generation '-OmitSchema is not supported for SqlServer; extended properties require a schema.' 1
}
if ($FoldUnquotedIdentifiers -and $Dialect -notin @('Oracle', 'OracleAnnotations', 'PostgreSql')) {
    Exit-Generation '-FoldUnquotedIdentifiers applies only to Oracle and PostgreSql dialects.' 1
}
if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
    Exit-Generation "Model file not found: $Path" 2
}

$modelBytes = [System.IO.File]::ReadAllBytes((Resolve-Path -LiteralPath $Path).ProviderPath)
if ($modelBytes.Length -gt 1MB) {
    Exit-Generation "Model exceeds the designer's 1 MiB size limit; no SQL generated." 1
}
try {
    $modelText = [System.Text.UTF8Encoding]::new($false, $true).GetString($modelBytes)
}
catch {
    Exit-Generation "Model is not valid UTF-8: $($_.Exception.Message)" 1
}
if ($modelText.Length -gt 0 -and $modelText[0] -eq [char]0xFEFF) {
    $modelText = $modelText.Substring(1)
}

$validation = & $validatorPath -Path $Path -RequireGovernanceMetadata *>&1
$validationExit = $LASTEXITCODE
foreach ($line in $validation) { [Console]::Error.WriteLine([string]$line) }
if ($validationExit -ne 0) {
    Exit-Generation 'Model validation failed; no SQL generated.' $validationExit
}

$settings = [System.Xml.XmlReaderSettings]::new()
$settings.DtdProcessing = [System.Xml.DtdProcessing]::Prohibit
$settings.XmlResolver = $null
$reader = [System.Xml.XmlReader]::Create([System.IO.StringReader]::new($modelText), $settings)
try {
    $document = [System.Xml.XmlDocument]::new()
    $document.XmlResolver = $null
    $document.Load($reader)
}
finally {
    $reader.Dispose()
}

function Get-ChildText([System.Xml.XmlElement]$Element, [string]$Name) {
    foreach ($child in $Element.ChildNodes) {
        if ($child.NodeType -eq [System.Xml.XmlNodeType]::Element -and $child.LocalName -ceq $Name) {
            return $child.InnerText.Trim()
        }
    }
    return ''
}

function ConvertFrom-TrailerValue([string]$Value) {
    $options = [System.Text.RegularExpressions.RegexOptions]::IgnoreCase
    $Value = [regex]::Replace($Value, '%3B', ';', $options)
    $Value = [regex]::Replace($Value, '%3D', '=', $options)
    $Value = [regex]::Replace($Value, '%7B', '{', $options)
    $Value = [regex]::Replace($Value, '%7D', '}', $options)
    return [regex]::Replace($Value, '%25', '%', $options)
}

function Get-ColumnCommentData([string]$Comment) {
    $match = [regex]::Match(
        $Comment,
        '(?s)^(?<description>.*?)\s*@bcgov\{RecordsSchedule=(?<schedule>[^{}]*)\}\s*$')
    if (-not $match.Success) {
        return [pscustomobject]@{ Description = $Comment; RecordsSchedule = '' }
    }
    return [pscustomobject]@{
        Description = $match.Groups['description'].Value.TrimEnd()
        RecordsSchedule = ConvertFrom-TrailerValue $match.Groups['schedule'].Value
    }
}

function ConvertTo-TrailerValue([string]$Value) {
    $builder = [System.Text.StringBuilder]::new()
    foreach ($character in $Value.ToCharArray()) {
        switch ($character) {
            '%' { [void]$builder.Append('%25') }
            ';' { [void]$builder.Append('%3B') }
            '=' { [void]$builder.Append('%3D') }
            '{' { [void]$builder.Append('%7B') }
            '}' { [void]$builder.Append('%7D') }
            default { [void]$builder.Append($character) }
        }
    }
    return $builder.ToString()
}

function Join-CommentTrailer([string]$Description, [System.Collections.Specialized.OrderedDictionary]$Metadata) {
    $pairs = foreach ($entry in $Metadata.GetEnumerator()) {
        if ($entry.Value) { '{0}={1}' -f $entry.Key, (ConvertTo-TrailerValue $entry.Value) }
    }
    $pairs = @($pairs)
    if ($pairs.Count -eq 0) { return $Description }
    $trailer = '@bcgov{' + ($pairs -join ';') + '}'
    if ($Description) { return "$Description $trailer" }
    return $trailer
}

function ConvertTo-SqlLiteral([string]$Value) {
    if ($Dialect -eq 'MySql') {
        $escaped = $Value.Replace('\', '\\').Replace("'", "''").Replace("`r", '\r').Replace("`n", '\n')
        return "'$escaped'"
    }
    $escaped = $Value.Replace("'", "''")
    if ($Dialect -eq 'SqlServer') { return "N'$escaped'" }
    return "'$escaped'"
}

# Keeps model-supplied names from ending a single-line SQL comment early.
function ConvertTo-CommentText([string]$Value) {
    return [regex]::Replace($Value, '[\p{Cc}\u2028\u2029]', '?')
}

function Test-IdentifierLength([string]$Name) {
    $limit = 0
    $length = $Name.Length
    $unit = 'characters'
    switch ($Dialect) {
        'SqlServer' { $limit = 128 }
        'MySql' { $limit = 64 }
        'PostgreSql' { $limit = 63; $length = [System.Text.Encoding]::UTF8.GetByteCount($Name); $unit = 'bytes' }
        default { $limit = 128; $length = [System.Text.Encoding]::UTF8.GetByteCount($Name); $unit = 'bytes' }
    }
    if ($length -gt $limit) {
        $script:errors.Add("Identifier '$(ConvertTo-CommentText $Name)' is $length $unit; $Dialect allows $limit.")
    }
}

function ConvertTo-Identifier([string]$Name) {
    Test-IdentifierLength $Name
    switch ($Dialect) {
        'SqlServer' { return '[' + $Name.Replace(']', ']]') + ']' }
        'MySql' { return '`' + $Name.Replace('`', '``') + '`' }
        { $_ -in @('Oracle', 'OracleAnnotations') } {
            if ($Name.Contains('"')) {
                $script:errors.Add("Oracle identifiers cannot contain double quotes: $(ConvertTo-CommentText $Name)")
                return '"?"'
            }
            if ($FoldUnquotedIdentifiers -and $Name -match '^[A-Za-z][A-Za-z0-9_$#]*$') {
                $Name = $Name.ToUpperInvariant()
            }
            return '"' + $Name + '"'
        }
        default {
            if ($FoldUnquotedIdentifiers -and $Name -match '^[A-Za-z_][A-Za-z0-9_$]*$') {
                $Name = $Name.ToLowerInvariant()
            }
            return '"' + $Name.Replace('"', '""') + '"'
        }
    }
}

function Get-QualifiedName([string]$Schema, [string]$Table, [string]$Column) {
    $parts = [System.Collections.Generic.List[string]]::new()
    if (-not $OmitSchema) { $parts.Add((ConvertTo-Identifier $Schema)) }
    $parts.Add((ConvertTo-Identifier $Table))
    if ($Column) { $parts.Add((ConvertTo-Identifier $Column)) }
    return $parts -join '.'
}

function Test-Limit([string]$Value, [string]$Location, [string]$Kind) {
    $limit = $null
    $length = $Value.Length
    $unit = 'characters'
    switch ($Dialect) {
        'SqlServer' { $limit = 7500; $length = [System.Text.Encoding]::Unicode.GetByteCount($Value); $unit = 'bytes' }
        'MySql' { $limit = if ($Kind -eq 'table') { 2048 } else { 1024 } }
        { $_ -in @('Oracle', 'OracleAnnotations') } {
            $limit = 4000
            if ($Kind -ne 'annotation') { $length = [System.Text.Encoding]::UTF8.GetByteCount($Value); $unit = 'bytes' }
        }
    }
    if ($limit -and $length -gt $limit) {
        $script:errors.Add("${Location}: $Kind metadata is $length $unit; $Dialect allows $limit.")
    }
}

function Format-SqlServerProperty([string]$Schema, [string]$Table, [string]$Column, [string]$Name, [string]$Value) {
    $levels = "@level0type = N'SCHEMA', @level0name = $(ConvertTo-SqlLiteral $Schema), @level1type = N'TABLE', @level1name = $(ConvertTo-SqlLiteral $Table)"
    $lookup = "N'SCHEMA', $(ConvertTo-SqlLiteral $Schema), N'TABLE', $(ConvertTo-SqlLiteral $Table), NULL, NULL"
    if ($Column) {
        $levels += ", @level2type = N'COLUMN', @level2name = $(ConvertTo-SqlLiteral $Column)"
        $lookup = "N'SCHEMA', $(ConvertTo-SqlLiteral $Schema), N'TABLE', $(ConvertTo-SqlLiteral $Table), N'COLUMN', $(ConvertTo-SqlLiteral $Column)"
    }
    $arguments = "@name = N'$Name', @value = $(ConvertTo-SqlLiteral $Value), $levels"
    return @(
        "IF EXISTS (SELECT 1 FROM sys.fn_listextendedproperty(N'$Name', $lookup))"
        "    EXEC sys.sp_updateextendedproperty $arguments;"
        'ELSE'
        "    EXEC sys.sp_addextendedproperty $arguments;"
    )
}

function Format-SqlServerPropertyDrop([string]$Schema, [string]$Table, [string]$Column, [string]$Name) {
    $levels = "@level0type = N'SCHEMA', @level0name = $(ConvertTo-SqlLiteral $Schema), @level1type = N'TABLE', @level1name = $(ConvertTo-SqlLiteral $Table), @level2type = N'COLUMN', @level2name = $(ConvertTo-SqlLiteral $Column)"
    $lookup = "N'SCHEMA', $(ConvertTo-SqlLiteral $Schema), N'TABLE', $(ConvertTo-SqlLiteral $Table), N'COLUMN', $(ConvertTo-SqlLiteral $Column)"
    return @(
        "IF EXISTS (SELECT 1 FROM sys.fn_listextendedproperty(N'$Name', $lookup))"
        "    EXEC sys.sp_dropextendedproperty @name = N'$Name', $levels;"
    )
}

function Format-OracleAnnotation([string]$Target, [string]$Column, [string]$Name, [string]$Value) {
    $drop = "ANNOTATIONS (DROP IF EXISTS ""$Name"")"
    $add = "ANNOTATIONS (ADD ""$Name"" $(ConvertTo-SqlLiteral $Value))"
    if ($Column) {
        $columnName = ConvertTo-Identifier $Column
        return @("ALTER TABLE $Target MODIFY ($columnName $drop);", "ALTER TABLE $Target MODIFY ($columnName $add);")
    }
    return @("ALTER TABLE $Target $drop;", "ALTER TABLE $Target $add;")
}

function Format-OracleAnnotationDrop([string]$Target, [string]$Column, [string]$Name) {
    $drop = "ANNOTATIONS (DROP IF EXISTS ""$Name"")"
    if ($Column) {
        $columnName = ConvertTo-Identifier $Column
        return "ALTER TABLE $Target MODIFY ($columnName $drop);"
    }
    return "ALTER TABLE $Target $drop;"
}

$lines = [System.Collections.Generic.List[string]]::new()
$lines.Add("-- Generated by Crow New-DataModelMetadataSql.ps1 for $Dialect. Review before applying.")
switch ($Dialect) {
    'PostgreSql' { $lines.Add('SET standard_conforming_strings = on;') }
    { $_ -in @('Oracle', 'OracleAnnotations') } { $lines.Add('-- In SQL*Plus or SQLcl, run SET DEFINE OFF first so ampersands stay literal.') }
    'MySql' { $lines.Add('-- Assumes the default sql_mode without NO_BACKSLASH_ESCAPES.') }
}

foreach ($table in $document.DocumentElement.ChildNodes) {
    if ($table.NodeType -ne [System.Xml.XmlNodeType]::Element -or $table.LocalName -cne 'table') { continue }
    $tableName = $table.GetAttribute('name').Trim()
    $schema = $table.GetAttribute('schema').Trim()
    if (-not $schema) {
        $schema = $defaultSchema
        if ($Dialect -ne 'SqlServer' -and -not $OmitSchema) {
            $script:errors.Add("[$(ConvertTo-CommentText $tableName)] has no schema; '$defaultSchema' is a SQL Server default. Set the schema or use -OmitSchema.")
        }
    }
    $tableLocation = "[$schema].[$tableName]"
    $tableTarget = Get-QualifiedName $schema $tableName $null
    $description = Get-ChildText $table 'comment'
    $schedule = Get-ChildText $table 'records-schedule'
    $lines.Add('')
    $lines.Add("-- Table $(ConvertTo-CommentText $tableLocation)")

    switch ($Dialect) {
        'SqlServer' {
            foreach ($pair in @(@($descriptionName, $description), @($scheduleName, $schedule))) {
                if (-not $pair[1]) { continue }
                Test-Limit $pair[1] $tableLocation 'table'
                $lines.AddRange([string[]](Format-SqlServerProperty $schema $tableName $null $pair[0] $pair[1]))
            }
        }
        'OracleAnnotations' {
            if ($description) {
                Test-Limit $description $tableLocation 'table'
                $lines.Add("COMMENT ON TABLE $tableTarget IS $(ConvertTo-SqlLiteral $description);")
            }
            if ($schedule) {
                Test-Limit $schedule $tableLocation 'annotation'
                $lines.AddRange([string[]](Format-OracleAnnotation $tableTarget $null $scheduleName $schedule))
            }
        }
        default {
            $metadata = [ordered]@{ $scheduleName = $schedule }
            $comment = Join-CommentTrailer $description $metadata
            if ($comment) {
                Test-Limit $comment $tableLocation 'table'
                if ($Dialect -eq 'MySql') {
                    $lines.Add("ALTER TABLE $tableTarget COMMENT = $(ConvertTo-SqlLiteral $comment);")
                }
                else {
                    $lines.Add("COMMENT ON TABLE $tableTarget IS $(ConvertTo-SqlLiteral $comment);")
                }
            }
        }
    }

    foreach ($row in $table.ChildNodes) {
        if ($row.NodeType -ne [System.Xml.XmlNodeType]::Element -or $row.LocalName -cne 'row') { continue }
        $columnName = $row.GetAttribute('name')
        $location = "$tableLocation.[$columnName]"
        $columnTarget = Get-QualifiedName $schema $tableName $columnName
        $columnComment = Get-ColumnCommentData (Get-ChildText $row 'comment')
        $columnDescription = $columnComment.Description
        $classification = Get-ChildText $row 'classification'
        $columnSchedule = $columnComment.RecordsSchedule

        switch ($Dialect) {
            'SqlServer' {
                foreach ($pair in @(
                    @($descriptionName, $columnDescription),
                    @($classificationName, $classification),
                    @($scheduleName, $columnSchedule)
                )) {
                    if (-not $pair[1]) { continue }
                    Test-Limit $pair[1] $location 'column'
                    $lines.AddRange([string[]](Format-SqlServerProperty $schema $tableName $columnName $pair[0] $pair[1]))
                }
                if (-not $columnSchedule) {
                    $lines.AddRange([string[]](Format-SqlServerPropertyDrop $schema $tableName $columnName $scheduleName))
                }
                if ($IncludeSensitivityClassification -and $classification) {
                    $lines.Add("ADD SENSITIVITY CLASSIFICATION TO $columnTarget WITH (LABEL = $(ConvertTo-SqlLiteral $classification), RANK = $($sensitivityRanks[$classification]));")
                }
            }
            'OracleAnnotations' {
                if ($columnDescription) {
                    Test-Limit $columnDescription $location 'column'
                    $lines.Add("COMMENT ON COLUMN $columnTarget IS $(ConvertTo-SqlLiteral $columnDescription);")
                }
                if ($classification) {
                    $lines.AddRange([string[]](Format-OracleAnnotation $tableTarget $columnName $classificationName $classification))
                }
                if ($columnSchedule) {
                    Test-Limit $columnSchedule $location 'annotation'
                    $lines.AddRange([string[]](Format-OracleAnnotation $tableTarget $columnName $scheduleName $columnSchedule))
                }
                else {
                    $lines.Add((Format-OracleAnnotationDrop $tableTarget $columnName $scheduleName))
                }
            }
            default {
                $metadata = [ordered]@{
                    $classificationName = $classification
                    $scheduleName = $columnSchedule
                }
                $comment = Join-CommentTrailer $columnDescription $metadata
                if (-not $comment) { continue }
                Test-Limit $comment $location 'column'
                if ($Dialect -eq 'MySql') {
                    $lines.Add("-- Column $(ConvertTo-CommentText $location) requires its full definition; add this clause in a reviewed MODIFY COLUMN:")
                    $lines.Add("--   COMMENT $(ConvertTo-SqlLiteral $comment)")
                }
                else {
                    $lines.Add("COMMENT ON COLUMN $columnTarget IS $(ConvertTo-SqlLiteral $comment);")
                }
            }
        }
    }
}

if ($script:errors.Count -gt 0) {
    foreach ($message in $script:errors) { [Console]::Error.WriteLine("ERROR: $message") }
    Exit-Generation "Metadata generation failed: $($script:errors.Count) error(s); no SQL written." 1
}

$output = ($lines -join [Environment]::NewLine) + [Environment]::NewLine
if ($OutFile) {
    [System.IO.File]::WriteAllText(
        $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutFile),
        $output,
        [System.Text.UTF8Encoding]::new($false))
}
else {
    [Console]::Out.Write($output)
}
exit 0
