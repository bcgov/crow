<!-- Crow portability note: migrated reference guidance; validate project-specific conventions and treat paths, versions, and platform choices as examples unless local evidence confirms them. -->

# SQL Server Native Data Classification

**Scope**: SQL Server 2019+ native sensitivity classification using `ADD SENSITIVITY CLASSIFICATION`.

Native classification vs. extended properties:
- Stored in `sys.sensitivity_classifications` (dedicated DMV, not generic key/value)
- Surfaced in SSMS Data Discovery & Classification GUI
- Recognized by Microsoft Purview, Defender for SQL, compliance scanning tools
- Supports `RANK` - machine-readable severity integer
- Requires `ALTER ANY SENSITIVITY CLASSIFICATION` permission

**Scope limit**: `ADD SENSITIVITY CLASSIFICATION` applies to **table columns only**.  
For views, stored procedures, and table-level labels, use
`sp_addextendedproperty` (see `extended-properties-templates.md`).

### Version Requirements

| Feature | Minimum Version |
|---|---|
| `ADD SENSITIVITY CLASSIFICATION` T-SQL | SQL Server 2019 (150) |
| `sys.sensitivity_classifications` DMV | SQL Server 2019 (150) |
| SSMS Data Discovery & Classification GUI | SSMS 18.0+ |
| DACPAC native serialization | SSDT 17.8+ (partial) - use post-deploy scripts to be safe |
| `RANK` parameter | SQL Server 2019 (150) |

---

## Organization Classification Taxonomy

### Information Types

| Information Type | Description | Example Values |
|---|---|---|
| `Unreviewed` | Not yet assessed - **default for new columns** | *(any unreviewed column)* |
| `Banking` | Bank account data | Account numbers, routing numbers |
| `Contact Info` | Contact details of a person | Address, city, postal code, phone, email |
| `Credentials` | Authentication credentials | Username, password, IDIR, BCeID |
| `Credit Card` | Payment card data | Card numbers, expiry, CVV |
| `Date of Birth` | Birth-related data | Birthday, birth year |
| `Financial` | Financial transaction data | Amounts, invoices, payments, tax |
| `Free-form Text` | Unstructured text | Comments, descriptions, memo, notes |
| `Health` | Health identifier data | Health number, PHN, MSP number |
| `Identification` | Government-issued ID data | Passport number, driver's license |
| `Name` | Person's name | First name, last name, alias |
| `Networking` | Network infrastructure data | IP address, MAC address |
| `Personal` | Demographic personal data | Gender, race, indigeneity, ability, education |
| `Other` | Catch-all - no other type fits | Reference codes, generic attributes |
| `SIN` | Social Insurance Number | SIN |

> Use `Personal` for demographic attributes. Use `Other` only when genuinely no other type fits. Confirm with Privacy Officer.

### Sensitivity Labels

Table-level label = highest label of any column it contains. Set table-level label via `sp_addextendedproperty`.

| Label | RANK | Description |
|---|---|---|
| `Unreviewed` | `NONE` | Not yet assessed - default |
| `Public` | `LOW` | No harm from disclosure; no personal information |
| `Protected A` | `MEDIUM` | Could cause harm or embarrassment (home address, DOB, contact info) |
| `Protected B` | `HIGH` | Could cause serious harm - reputation, financial loss (SIN, health, financial) |
| `Protected C` | `CRITICAL` | Extremely grave harm or loss of life; cabinet-level - escalate to Privacy Officer |

---

## T-SQL Syntax

### ADD SENSITIVITY CLASSIFICATION

```sql
-- Basic syntax (SQL Server 2019+)
ADD SENSITIVITY CLASSIFICATION TO <schema>.<table>.<column>
WITH (
    LABEL            = '<sensitivity_label>',
    INFORMATION_TYPE = '<information_type>',
    RANK             = <NONE | LOW | MEDIUM | HIGH | CRITICAL>
);
```

### UPDATE (DROP + ADD)

There is no `ALTER SENSITIVITY CLASSIFICATION`. Drop and re-add:

```sql
DROP SENSITIVITY CLASSIFICATION FROM Dimension.Customer.PHN;

ADD SENSITIVITY CLASSIFICATION TO Dimension.Customer.PHN
WITH (LABEL = 'Protected B', INFORMATION_TYPE = 'Health', RANK = HIGH);
```

### Safe Upsert Pattern (Idempotent)

```sql
IF EXISTS (
    SELECT 1 FROM sys.sensitivity_classifications sc
    JOIN sys.columns c ON sc.object_id = c.object_id AND sc.column_id = c.column_id
    WHERE sc.object_id = OBJECT_ID(N'Dimension.Customer')
      AND c.[name] = N'PHN'
)
    DROP SENSITIVITY CLASSIFICATION FROM Dimension.Customer.PHN;

ADD SENSITIVITY CLASSIFICATION TO Dimension.Customer.PHN
WITH (LABEL = 'Protected B', INFORMATION_TYPE = 'Health', RANK = HIGH);
```

---

## Label-to-RANK Mapping

Always use this mapping consistently:

```sql
-- 'Unreviewed'  -> RANK = NONE
-- 'Public'      -> RANK = LOW
-- 'Protected A' -> RANK = MEDIUM
-- 'Protected B' -> RANK = HIGH
-- 'Protected C' -> RANK = CRITICAL
```

---

## Column Classification Templates by Type

Each example uses the upsert pattern. Repeat for each column in the table.

```sql
-- Health (Protected B / HIGH)
ADD SENSITIVITY CLASSIFICATION TO Dimension.Patient.PHN
    WITH (LABEL = 'Protected B', INFORMATION_TYPE = 'Health', RANK = HIGH);

-- SIN (Protected B / HIGH)
ADD SENSITIVITY CLASSIFICATION TO Dimension.Employee.SIN
    WITH (LABEL = 'Protected B', INFORMATION_TYPE = 'SIN', RANK = HIGH);

-- Name (Protected A / MEDIUM)
ADD SENSITIVITY CLASSIFICATION TO Dimension.Customer.FirstName
    WITH (LABEL = 'Protected A', INFORMATION_TYPE = 'Name', RANK = MEDIUM);
-- same pattern for LastName, FullName, Alias

-- Contact Info (Protected A / MEDIUM)
ADD SENSITIVITY CLASSIFICATION TO Dimension.Customer.AddressLine1
    WITH (LABEL = 'Protected A', INFORMATION_TYPE = 'Contact Info', RANK = MEDIUM);
-- same pattern for City, PostalCode, Phone, Email

-- Date of Birth (Protected A / MEDIUM)
ADD SENSITIVITY CLASSIFICATION TO Dimension.Customer.DateOfBirth
    WITH (LABEL = 'Protected A', INFORMATION_TYPE = 'Date of Birth', RANK = MEDIUM);

-- Credentials (Protected B / HIGH)
ADD SENSITIVITY CLASSIFICATION TO Dimension.User.IDIRUsername
    WITH (LABEL = 'Protected B', INFORMATION_TYPE = 'Credentials', RANK = HIGH);

-- Financial (Protected B / HIGH)
ADD SENSITIVITY CLASSIFICATION TO Fact.Payment.PaymentAmount
    WITH (LABEL = 'Protected B', INFORMATION_TYPE = 'Financial', RANK = HIGH);

-- Personal / Demographic (Protected A / MEDIUM)
ADD SENSITIVITY CLASSIFICATION TO Dimension.Person.Gender
    WITH (LABEL = 'Protected A', INFORMATION_TYPE = 'Personal', RANK = MEDIUM);

-- Public reference data (Public / LOW)
ADD SENSITIVITY CLASSIFICATION TO Dimension.Region.RegionCode
    WITH (LABEL = 'Public', INFORMATION_TYPE = 'Other', RANK = LOW);
```

---

## Audit Queries

```sql
-- Full classification inventory (use for privacy impact assessments)
SELECT OBJECT_SCHEMA_NAME(sc.object_id) AS SchemaName, OBJECT_NAME(sc.object_id) AS TableName,
    c.[name] AS ColumnName, TYPE_NAME(c.user_type_id) AS DataType,
    sc.information_type AS InformationType, sc.label AS SensitivityLabel, sc.rank_desc AS Rank
FROM sys.sensitivity_classifications sc
JOIN sys.columns c ON sc.object_id = c.object_id AND sc.column_id = c.column_id
JOIN sys.tables t  ON c.object_id = t.object_id AND t.is_ms_shipped = 0
ORDER BY sc.rank DESC, SchemaName, TableName, c.column_id;
```

```sql
-- Columns with no classification (unclassified)
SELECT OBJECT_SCHEMA_NAME(c.object_id) AS SchemaName, OBJECT_NAME(c.object_id) AS TableName,
    c.[name] AS ColumnName, TYPE_NAME(c.user_type_id) AS DataType
FROM sys.columns c JOIN sys.tables t ON c.object_id = t.object_id AND t.is_ms_shipped = 0
WHERE OBJECT_SCHEMA_NAME(c.object_id) NOT IN ('staging','sys','INFORMATION_SCHEMA')
  AND NOT EXISTS (SELECT 1 FROM sys.sensitivity_classifications sc
    WHERE sc.object_id = c.object_id AND sc.column_id = c.column_id)
ORDER BY SchemaName, TableName, c.column_id;
```

```sql
-- Protected B and C columns (highest priority for access control review)
SELECT OBJECT_SCHEMA_NAME(sc.object_id) AS SchemaName, OBJECT_NAME(sc.object_id) AS TableName,
    c.[name] AS ColumnName, sc.information_type AS InformationType,
    sc.label AS SensitivityLabel, sc.rank_desc AS Rank
FROM sys.sensitivity_classifications sc
JOIN sys.columns c ON sc.object_id = c.object_id AND sc.column_id = c.column_id
WHERE sc.rank >= 20   -- HIGH (Protected B) and CRITICAL (Protected C)
ORDER BY sc.rank DESC, SchemaName, TableName;
```

```sql
-- Summary by label
SELECT sc.label AS SensitivityLabel, sc.rank_desc AS Rank,
    COUNT(*) AS ColumnCount, COUNT(DISTINCT sc.object_id) AS TableCount
FROM sys.sensitivity_classifications sc
GROUP BY sc.label, sc.rank_desc, sc.rank
ORDER BY sc.rank DESC;
```

```sql
-- Tables with highest column rank (for assigning table-level SensitivityLabel)
SELECT OBJECT_SCHEMA_NAME(sc.object_id) AS SchemaName, OBJECT_NAME(sc.object_id) AS TableName,
    MAX(sc.rank_desc) AS MaxRank,
    CASE MAX(sc.rank) WHEN 30 THEN 'Protected C' WHEN 25 THEN 'Protected C'
        WHEN 20 THEN 'Protected B' WHEN 10 THEN 'Protected A'
        WHEN 0  THEN 'Public' ELSE 'Unreviewed' END AS RecommendedTableLabel
FROM sys.sensitivity_classifications sc
JOIN sys.tables t ON sc.object_id = t.object_id AND t.is_ms_shipped = 0
GROUP BY sc.object_id
ORDER BY MAX(sc.rank) DESC;
```

---

## Bulk Classification Generation Script

Generates `ADD SENSITIVITY CLASSIFICATION` statements from existing `InformationType`/`SensitivityLabel` extended properties (migration path):

```sql
SELECT
    'IF EXISTS (SELECT 1 FROM sys.sensitivity_classifications sc ' +
    'JOIN sys.columns c ON sc.object_id = c.object_id AND sc.column_id = c.column_id ' +
    'WHERE sc.object_id = OBJECT_ID(N''' + QUOTENAME(OBJECT_SCHEMA_NAME(c.object_id)) + '.' +
        QUOTENAME(OBJECT_NAME(c.object_id)) + ''') AND c.[name] = N''' + c.[name] + ''') ' + CHAR(13) +
    '    DROP SENSITIVITY CLASSIFICATION FROM ' + QUOTENAME(OBJECT_SCHEMA_NAME(c.object_id)) + '.' +
        QUOTENAME(OBJECT_NAME(c.object_id)) + '.' + QUOTENAME(c.[name]) + ';' + CHAR(13) +
    'ADD SENSITIVITY CLASSIFICATION TO ' + QUOTENAME(OBJECT_SCHEMA_NAME(c.object_id)) + '.' +
        QUOTENAME(OBJECT_NAME(c.object_id)) + '.' + QUOTENAME(c.[name]) + CHAR(13) +
    '    WITH (LABEL = ''' + CAST(sl.value AS NVARCHAR(100)) + ''', ' +
          'INFORMATION_TYPE = ''' + CAST(it.value AS NVARCHAR(100)) + ''', ' +
          'RANK = ' + CASE CAST(sl.value AS NVARCHAR(100))
              WHEN 'Protected C' THEN 'CRITICAL' WHEN 'Protected B' THEN 'HIGH'
              WHEN 'Protected A' THEN 'MEDIUM'   WHEN 'Public'      THEN 'LOW'
              ELSE 'NONE' END + ');' AS GeneratedScript
FROM sys.columns c
JOIN sys.extended_properties it ON it.major_id = c.object_id AND it.minor_id = c.column_id
    AND it.class = 1 AND it.[name] = N'InformationType'
JOIN sys.extended_properties sl ON sl.major_id = c.object_id AND sl.minor_id = c.column_id
    AND sl.class = 1 AND sl.[name] = N'SensitivityLabel'
WHERE OBJECTPROPERTY(c.object_id, 'IsTable') = 1
  AND OBJECTPROPERTY(c.object_id, 'IsMsShipped') = 0
  AND CAST(sl.value AS NVARCHAR(100)) <> N'Unreviewed'
ORDER BY OBJECT_SCHEMA_NAME(c.object_id), OBJECT_NAME(c.object_id), c.column_id;
```

---

## SSDT Deployment Pattern

Classification scripts do **not** serialize in the DACPAC model. Place in post-deploy scripts:

```
Database\Scripts\Post-Deployment\DataClassification\
    Dimension.Customer.Classification.sql
    Dimension.Employee.Classification.sql
    Fact.Payment.Classification.sql
```

Each file uses the idempotent upsert pattern (DROP if exists, then ADD). Also set the table-level `SensitivityLabel` extended property using the upsert pattern from `extended-properties-templates.md`.

---

## Required Permissions

```sql
GRANT ALTER ANY SENSITIVITY CLASSIFICATION TO [DBA_Role];
GRANT VIEW ANY SENSITIVITY CLASSIFICATION  TO [Reporting_Role];
```

---

## Column Name Patterns - Suggested Classification

| Column name contains | Suggested Information Type | Suggested Label |
|---|---|---|
| `PHN`, `HealthNumber`, `MSP` | `Health` | Protected B |
| `SIN`, `SocialInsurance` | `SIN` | Protected B |
| `FirstName`, `LastName`, `FullName`, `Alias` | `Name` | Protected A |
| `DOB`, `DateOfBirth`, `BirthDate`, `BirthYear` | `Date of Birth` | Protected A |
| `Address`, `Street`, `City`, `PostalCode`, `ZipCode` | `Contact Info` | Protected A |
| `Phone`, `Cell`, `Mobile`, `Fax` | `Contact Info` | Protected A |
| `Email`, `EmailAddress` | `Contact Info` | Protected A |
| `IDIR`, `BCeID`, `Username`, `Password` | `Credentials` | Protected B |
| `CreditCard`, `CardNumber`, `CVV`, `ExpiryDate` | `Credit Card` | Protected B |
| `Amount`, `Payment`, `Invoice`, `Tax`, `Salary` | `Financial` | Protected B |
| `IPAddress`, `MACAddress` | `Networking` | Protected A |
| `Passport`, `DriversLicense`, `LicenseNumber` | `Identification` | Protected A |
| `Gender`, `Race`, `Indigeneity`, `Disability`, `Ability` | `Personal` | Protected A |
| `Comment`, `Note`, `Description`, `Memo` | `Free-form Text` | Protected A* |
| `RegionCode`, `ProductCode`, `StatusCode` | `Other` | Public |

> *Free-form text may contain any sensitivity level of user-entered data. Classify as Protected A minimum and flag for content-scanning review.

---

## References

- [ADD SENSITIVITY CLASSIFICATION (T-SQL) - Microsoft Learn](https://learn.microsoft.com/en-us/sql/t-sql/statements/add-sensitivity-classification-transact-sql)
- [sys.sensitivity_classifications - Microsoft Learn](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-sensitivity-classifications-transact-sql)
- `extended-properties-templates.md` - extended properties approach (for tables, views, SPs)
- BC Government information classification framework