<!-- Crow portability note: migrated reference guidance; validate project-specific conventions and treat paths, versions, and platform choices as examples unless local evidence confirms them. -->

# Extended Properties Documentation Templates

SQL Server extended properties are the standard mechanism for inline database documentation.
Queryable, visible in SSMS tooltips, and survive schema deployments when managed correctly.

---

## Core T-SQL Functions

```sql
-- Add
EXEC sys.sp_addextendedproperty
    @name  = N'<PropertyName>', @value = N'<PropertyValue>',
    @level0type = N'SCHEMA', @level0name = N'<schema>',
    @level1type = N'<ObjectType>', @level1name = N'<ObjectName>',
    [@level2type = N'<SubObjectType>', @level2name = N'<SubObjectName>']

-- Update
EXEC sys.sp_updateextendedproperty  -- same parameters as sp_addextendedproperty

-- Drop
EXEC sys.sp_dropextendedproperty    -- same parameters (no @value)

-- Query all (object + column level)
SELECT
    OBJECT_SCHEMA_NAME(ep.major_id) AS SchemaName,
    OBJECT_NAME(ep.major_id)        AS ObjectName,
    COALESCE(c.[name], '')          AS ColumnName,
    ep.[name]                       AS PropertyName,
    CAST(ep.[value] AS NVARCHAR(MAX)) AS PropertyValue
FROM sys.extended_properties ep
LEFT JOIN sys.columns c ON ep.major_id = c.object_id AND ep.minor_id = c.column_id
WHERE ep.class = 1
ORDER BY SchemaName, ObjectName, ColumnName, PropertyName
```

---

## Standard Property Names

| Property Name | Level | Description |
|---|---|---|
| `MS_Description` | Table, Column, View, SP, Function | Primary description - shown in SSMS tooltips. **Always set first.** |
| `BusinessDescription` | Table, Column | Business-friendly explanation for non-technical users |
| `SourceSystem` | Table, Column | Where data originates (e.g., `ERP - SAP`, `CRM - Salesforce`) |
| `SourceTable` | Table | Source table name in the originating system |
| `SourceColumn` | Column | Source column name in the originating system |
| `Grain` | Fact Table | One sentence describing the grain (e.g., `One row per daily product-customer transaction`) |
| `TableType` | Table | `Fact`, `Dimension`, `Bridge`, `Staging`, `Reference`, `Archive` |
| `SCDType` | Dimension Table | SCD handling: `1`, `2`, `3`, `6`, `None` |
| `ConformedDimension` | Dimension Table | `Yes` / `No` |
| `KeyColumn` | Column | `SurrogateKey`, `NaturalKey`, `ForeignKey`, `Measure`, `Attribute`, `Flag` |
| `InformationType` | Column | Category of data stored. See taxonomy below. Default new columns to `Unreviewed`. |
| `SensitivityLabel` | Column, Table | Sensitivity classification. See taxonomy below. Default new to `Unreviewed`. |
| `IsActive` | Table | `Yes` / `No` |
| `BusinessOwner` | Table | Team or person accountable for the data |
| `DataSteward` | Table | Person responsible for data quality |
| `RefreshFrequency` | Table | `Daily`, `Hourly`, `Weekly`, `Monthly`, `On-demand` |
| `CreatedDate` | Table | Date first created |
| `LastReviewedDate` | Table | Date documentation was last reviewed |
| `RelatedReport` | Table, View | Power BI or SSRS report that consumes this object |

---

## Data Classification Reference

Use exact casing as shown. Apply via `InformationType` and `SensitivityLabel` extended properties.

### Information Types (apply to columns)

| InformationType Value | Example Columns |
|---|---|
| `Unreviewed` | **Default for all new columns** |
| `Banking` | `BankAccountNumber`, `RoutingNumber`, `TransitNumber` |
| `Contact Info` | `AddressLine1`, `City`, `PostalCode`, `PhoneNumber`, `EmailAddress` |
| `Credentials` | `Username`, `PasswordHash`, `IDIRUsername`, `BCeIDUsername` |
| `Credit Card` | `CreditCardNumber`, `CardExpiry`, `CardType`, `CVV` |
| `Date of Birth` | `DateOfBirth`, `BirthYear`, `BirthDate` |
| `Financial` | `InvoiceAmount`, `PaymentAmount`, `TaxAmount`, `WageAmount` |
| `Free-form Text` | `Comments`, `Description`, `MemoField`, `Notes`, `Remarks` |
| `Health` | `HealthNumber`, `PHN`, `MSPNumber` |
| `Identification` | `PassportNumber`, `DriversLicenseNumber`, `IdentificationNumber` |
| `Name` | `FirstName`, `LastName`, `MiddleName`, `Alias`, `LegalName` |
| `Networking` | `IPAddress`, `MACAddress`, `HostName` |
| `Personal` | `Gender`, `Race`, `Indigeneity`, `Ability`, `Education` |
| `Other` | Data that fits no other category |
| `SIN` | `SIN`, `SocialInsuranceNumber` |

> Use `Personal` for demographic attributes. Use `Other` only when no other type fits. Confirm with Privacy Officer.

### Sensitivity Labels (apply to tables and columns)

Table-level label = highest label of any column it contains.

| SensitivityLabel Value | RANK (native) | Disclosure Risk |
|---|---|---|
| `Unreviewed` | NONE | **Default for all new objects** |
| `Public` | LOW | No harm; no personal information |
| `Protected A` | MEDIUM | Could cause harm or embarrassment (home address, DOB) |
| `Protected B` | HIGH | Serious harm - reputation, financial loss (SIN, health, financial) |
| `Protected C` | CRITICAL | Extremely grave harm or loss of life - cabinet-level; escalate to Privacy Officer |

---

## Object Templates

### Table Documentation

```sql
-- Fact table example
EXEC sys.sp_addextendedproperty
    @name  = N'MS_Description',
    @value = N'Sales transactions at daily product-customer-store grain. One row per line item on a sales order. Source: ERP order management system.',
    @level0type = N'SCHEMA', @level0name = N'Fact',
    @level1type = N'TABLE',  @level1name = N'SalesTransaction';

-- Additional properties follow same pattern:
EXEC sys.sp_addextendedproperty @name = N'Grain',
    @value = N'One row per sales order line item per day per product per customer per store',
    @level0type = N'SCHEMA', @level0name = N'Fact',
    @level1type = N'TABLE', @level1name = N'SalesTransaction';
-- Repeat for: TableType, SourceSystem, RefreshFrequency, BusinessOwner
```

Dimension table - same pattern; also set `SCDType` and `ConformedDimension`.

### Column Documentation

```sql
-- Surrogate key
EXEC sys.sp_addextendedproperty
    @name  = N'MS_Description',
    @value = N'Surrogate key. System-generated integer. PK and FK in all fact tables. Do not expose to end users.',
    @level0type = N'SCHEMA', @level0name = N'Dimension',
    @level1type = N'TABLE',  @level1name = N'Customer',
    @level2type = N'COLUMN', @level2name = N'CustomerKey';

EXEC sys.sp_addextendedproperty @name = N'KeyColumn', @value = N'SurrogateKey',
    @level0type = N'SCHEMA', @level0name = N'Dimension',
    @level1type = N'TABLE',  @level1name = N'Customer',
    @level2type = N'COLUMN', @level2name = N'CustomerKey';

-- Natural key - same pattern; set KeyColumn = 'NaturalKey', SourceSystem
-- SCD indicator - set MS_Description explaining 1 = current, 0 = historical
-- InformationType and SensitivityLabel columns - same pattern, @level2type = N'COLUMN'
```

### View Documentation

```sql
EXEC sys.sp_addextendedproperty
    @name  = N'MS_Description',
    @value = N'Aggregated daily sales summary by product and customer. Pre-joined view for report layer. Do not use in ETL.',
    @level0type = N'SCHEMA', @level0name = N'report',
    @level1type = N'VIEW',   @level1name = N'vw_SalesSummary';

EXEC sys.sp_addextendedproperty @name = N'RelatedReport', @value = N'Power BI: Sales Performance Dashboard',
    @level0type = N'SCHEMA', @level0name = N'report',
    @level1type = N'VIEW',   @level1name = N'vw_SalesSummary';
```

### Stored Procedure Documentation

```sql
EXEC sys.sp_addextendedproperty
    @name  = N'MS_Description',
    @value = N'ELT load for [Fact].[SalesTransaction]. Incremental load using HighWaterMark. Idempotent - safe to re-run.',
    @level0type = N'SCHEMA', @level0name = N'Fact',
    @level1type = N'PROCEDURE', @level1name = N'LoadSalesTransaction';

EXEC sys.sp_addextendedproperty @name = N'ExecutionContext',
    @value = N'ETL - called by SSIS package DW_Load.dtsx, step LoadFacts',
    @level0type = N'SCHEMA', @level0name = N'Fact',
    @level1type = N'PROCEDURE', @level1name = N'LoadSalesTransaction';
```

---

## Upsert Pattern (Safe for Deployment Scripts)

```sql
-- Idempotent upsert for any object-level property (minor_id = 0 for table, > 0 for column)
IF EXISTS (
    SELECT 1 FROM sys.extended_properties
    WHERE major_id = OBJECT_ID(N'Dimension.Customer')
      AND minor_id = 0
      AND class    = 1
      AND [name]   = N'MS_Description'
)
    EXEC sys.sp_updateextendedproperty
        @name = N'MS_Description', @value = N'<your description>',
        @level0type = N'SCHEMA', @level0name = N'Dimension',
        @level1type = N'TABLE',  @level1name = N'Customer';
ELSE
    EXEC sys.sp_addextendedproperty
        @name = N'MS_Description', @value = N'<your description>',
        @level0type = N'SCHEMA', @level0name = N'Dimension',
        @level1type = N'TABLE',  @level1name = N'Customer';
```

For column-level: add `AND minor_id = COLUMNPROPERTY(OBJECT_ID(N'Dimension.Customer'), N'ColumnName', 'ColumnId')` to the WHERE, and include `@level2type = N'COLUMN', @level2name = N'ColumnName'` in the EXEC.

---

## Audit Queries

```sql
-- Objects missing MS_Description
SELECT s.[name] AS SchemaName, t.[name] AS ObjectName, 'TABLE' AS ObjectType
FROM sys.tables t JOIN sys.schemas s ON t.[schema_id] = s.[schema_id]
WHERE t.is_ms_shipped = 0
  AND NOT EXISTS (SELECT 1 FROM sys.extended_properties ep
    WHERE ep.major_id = t.[object_id] AND ep.minor_id = 0
      AND ep.class = 1 AND ep.[name] = N'MS_Description')
UNION ALL
SELECT s.[name], v.[name], 'VIEW'
FROM sys.views v JOIN sys.schemas s ON v.[schema_id] = s.[schema_id]
WHERE v.is_ms_shipped = 0
  AND NOT EXISTS (SELECT 1 FROM sys.extended_properties ep
    WHERE ep.major_id = v.[object_id] AND ep.minor_id = 0
      AND ep.class = 1 AND ep.[name] = N'MS_Description')
UNION ALL
SELECT s.[name], p.[name], 'PROCEDURE'
FROM sys.procedures p JOIN sys.schemas s ON p.[schema_id] = s.[schema_id]
WHERE p.is_ms_shipped = 0
  AND NOT EXISTS (SELECT 1 FROM sys.extended_properties ep
    WHERE ep.major_id = p.[object_id] AND ep.minor_id = 0
      AND ep.class = 1 AND ep.[name] = N'MS_Description')
ORDER BY ObjectType, SchemaName, ObjectName;
```

```sql
-- Columns missing InformationType (not yet classified)
SELECT OBJECT_SCHEMA_NAME(c.object_id) AS SchemaName, OBJECT_NAME(c.object_id) AS TableName,
    c.[name] AS ColumnName, TYPE_NAME(c.user_type_id) AS DataType
FROM sys.columns c
WHERE OBJECTPROPERTY(c.object_id, 'IsMsShipped') = 0
  AND OBJECTPROPERTY(c.object_id, 'IsTable') = 1
  AND OBJECT_SCHEMA_NAME(c.object_id) NOT IN ('sys','INFORMATION_SCHEMA','staging')
  AND NOT EXISTS (SELECT 1 FROM sys.extended_properties ep
    WHERE ep.major_id = c.object_id AND ep.minor_id = c.column_id
      AND ep.class = 1 AND ep.[name] = N'InformationType')
ORDER BY SchemaName, TableName, c.column_id;
```

```sql
-- Full classification inventory
SELECT OBJECT_SCHEMA_NAME(c.object_id) AS SchemaName, OBJECT_NAME(c.object_id) AS TableName,
    c.[name] AS ColumnName, TYPE_NAME(c.user_type_id) AS DataType,
    CAST(it.value AS NVARCHAR(100)) AS InformationType,
    CAST(sl.value AS NVARCHAR(100)) AS SensitivityLabel
FROM sys.columns c
LEFT JOIN sys.extended_properties it
    ON it.major_id = c.object_id AND it.minor_id = c.column_id AND it.class = 1 AND it.[name] = N'InformationType'
LEFT JOIN sys.extended_properties sl
    ON sl.major_id = c.object_id AND sl.minor_id = c.column_id AND sl.class = 1 AND sl.[name] = N'SensitivityLabel'
WHERE OBJECTPROPERTY(c.object_id, 'IsMsShipped') = 0
  AND OBJECTPROPERTY(c.object_id, 'IsTable') = 1
  AND OBJECT_SCHEMA_NAME(c.object_id) NOT IN ('sys','INFORMATION_SCHEMA','staging')
  AND (it.value IS NOT NULL OR sl.value IS NOT NULL)
ORDER BY CAST(sl.value AS NVARCHAR(100)) DESC, SchemaName, TableName, c.column_id;
```

---

## SSDT Integration Note

In SQL Server Data Tools (`.sqlproj`), extended property scripts belong in `Scripts\Post-Deployment`:

```
Scripts\Post-Deployment\
  ExtendedProperties\
    Tables\
      Dimension.Customer.sql         -- MS_Description, TableType, SensitivityLabel
      Fact.SalesOrder.sql
    Columns\
      Dimension.Customer.Columns.sql -- InformationType, SensitivityLabel per column
    Views\
    Procedures\
```

- Always use the `IF EXISTS / sp_updateextendedproperty ELSE sp_addextendedproperty` upsert pattern for idempotency.
- Default all new columns to `InformationType = 'Unreviewed'` and `SensitivityLabel = 'Unreviewed'` pending formal privacy review.