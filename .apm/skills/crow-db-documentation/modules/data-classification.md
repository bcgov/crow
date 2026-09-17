# SQL Server Data Sensitivity and Classification

Load this module when D1 or D2 work includes privacy, sensitivity, or
classification. It complements `extended-properties.md`; it does not replace
the user confirmation gate.

## Two metadata systems

SQL Server 2019+ native classification applies to **table columns only**:

- `ADD SENSITIVITY CLASSIFICATION` stores metadata in
  `sys.sensitivity_classifications`;
- SSMS Data Discovery and Classification, Purview, and Defender can consume
  the native metadata;
- native classification requires `ALTER ANY SENSITIVITY CLASSIFICATION`;
- database, schema, table, view, procedure, function, trigger, and
  table-level labels still use extended properties;
- use table-level `SensitivityLabel` extended properties because native
  classification is column-only.

Do not claim native classification was applied when the task only generated
extended properties. State which metadata system each output uses.

## Supported versions and permissions

| Capability | Baseline |
|---|---|
| `ADD SENSITIVITY CLASSIFICATION` | SQL Server 2019 (compatibility level 150) |
| `sys.sensitivity_classifications` | SQL Server 2019 (150) |
| SSMS classification UI | SSMS 18+ |
| DACPAC serialization | SSDT 17.8+ is partial; prefer post-deploy scripts |
| Apply native classification | `ALTER ANY SENSITIVITY CLASSIFICATION` |
| Inspect native classification | `VIEW ANY SENSITIVITY CLASSIFICATION` |

If the SQL Server version or permissions are unknown, mark the capability
unverified and generate reviewable output instead of assuming it is available.
Never use impersonation or `EXECUTE AS` to bypass permissions.

## Organization taxonomy

Use exact values. `Unreviewed` is the default for new or unassessed fields.
Name-based matches are draft suggestions only; the user must confirm the
information type and sensitivity label before writing them.

| Information type | Typical examples |
|---|---|
| `Unreviewed` | Not yet assessed |
| `Banking` | Account, routing, transit number |
| `Contact Info` | Address, city, postal code, phone, email |
| `Credentials` | Username, password, IDIR, BCeID |
| `Credit Card` | Card number, expiry, CVV |
| `Date of Birth` | Birth date or year |
| `Financial` | Amount, invoice, payment, tax, wage |
| `Free-form Text` | Comments, descriptions, memo, notes |
| `Health` | Health number, PHN, MSP |
| `Identification` | Passport, driver's licence, government ID |
| `Name` | First, last, middle, alias, legal name |
| `Networking` | IP, MAC, host name |
| `Personal` | Gender, race, indigeneity, ability, education |
| `SIN` | Social Insurance Number |
| `Other` | Only when no more specific type applies |

Use `Personal` for demographic attributes. Use `Other` only after considering
the specific categories. Confirm sensitive or ambiguous classifications with
the appropriate privacy authority.

## Sensitivity labels and native ranks

The table-level label is the highest confirmed label of its columns. This
table-level value is an extended property; native SQL classification remains
column-level.

| Label | Native rank | Meaning |
|---|---|---|
| `Unreviewed` | `NONE` | Not assessed |
| `Public` | `LOW` | Disclosure causes no material harm |
| `Protected A` | `MEDIUM` | Could cause harm or embarrassment |
| `Protected B` | `HIGH` | Could cause serious harm, financial loss, or reputational damage |
| `Protected C` | `CRITICAL` | Exceptional risk; escalate to privacy authority |

Never assign `Protected B` or `Protected C` solely from a column name. Always
ask for confirmation. Free-form text may contain higher-risk content than its
name indicates and should be flagged for content-scanning review rather than
treated as automatically safe.

## Native T-SQL

Native classification applies to a column:

```sql
ADD SENSITIVITY CLASSIFICATION TO [schema].[table].[column]
WITH (
    LABEL = '<confirmed label>',
    INFORMATION_TYPE = '<confirmed information type>',
    RANK = <NONE | LOW | MEDIUM | HIGH | CRITICAL>
);
```

There is no `ALTER SENSITIVITY CLASSIFICATION`. A confirmed change is
drop-and-add:

```sql
DROP SENSITIVITY CLASSIFICATION
    FROM [schema].[table].[column];

ADD SENSITIVITY CLASSIFICATION TO [schema].[table].[column]
WITH (
    LABEL = '<confirmed label>',
    INFORMATION_TYPE = '<confirmed information type>',
    RANK = <rank>
);
```

For an idempotent script, test `sys.sensitivity_classifications` joined to
`sys.columns`, drop only when a classification exists, then add the confirmed
classification. Do not generate a drop-and-add for an unconfirmed draft.

The required mapping is:

```text
Unreviewed  -> NONE
Public      -> LOW
Protected A -> MEDIUM
Protected B -> HIGH
Protected C -> CRITICAL
```

## Audits

Use these shapes for live-provider implementations or validate equivalent
local metadata when working from exported definitions:

```sql
-- Classified columns
SELECT
    OBJECT_SCHEMA_NAME(sc.object_id) AS SchemaName,
    OBJECT_NAME(sc.object_id) AS TableName,
    c.[name] AS ColumnName,
    sc.information_type AS InformationType,
    sc.label AS SensitivityLabel,
    sc.rank_desc AS [Rank]
FROM sys.sensitivity_classifications AS sc
JOIN sys.columns AS c
  ON c.object_id = sc.object_id
 AND c.column_id = sc.column_id
JOIN sys.tables AS t
  ON t.object_id = c.object_id
 AND t.is_ms_shipped = 0
ORDER BY sc.rank DESC, SchemaName, TableName, c.column_id;
```

```sql
-- Unclassified user-table columns
SELECT
    OBJECT_SCHEMA_NAME(c.object_id) AS SchemaName,
    OBJECT_NAME(c.object_id) AS TableName,
    c.[name] AS ColumnName,
    TYPE_NAME(c.user_type_id) AS DataType
FROM sys.columns AS c
JOIN sys.tables AS t
  ON t.object_id = c.object_id
 AND t.is_ms_shipped = 0
WHERE OBJECT_SCHEMA_NAME(c.object_id)
      NOT IN (N'sys', N'INFORMATION_SCHEMA', N'staging')
  AND NOT EXISTS (
      SELECT 1
      FROM sys.sensitivity_classifications AS sc
      WHERE sc.object_id = c.object_id
        AND sc.column_id = c.column_id
  )
ORDER BY SchemaName, TableName, c.column_id;
```

Prioritize `Protected B` and `Protected C` for access-control review and
privacy follow-up. When assigning a table label, use the highest confirmed
column rank; do not infer a table label from an unconfirmed name heuristic.

## Draft heuristics

These are prompts for review, not automatic classifications:

| Name signal | Draft information type | Typical draft label |
|---|---|---|
| `PHN`, `HealthNumber`, `MSP` | `Health` | `Protected B` |
| `SIN`, `SocialInsurance` | `SIN` | `Protected B` |
| `FirstName`, `LastName`, `FullName`, `Alias` | `Name` | `Protected A` |
| `DOB`, `DateOfBirth`, `BirthDate`, `BirthYear` | `Date of Birth` | `Protected A` |
| `Address`, `City`, `PostalCode`, `Phone`, `Email` | `Contact Info` | `Protected A` |
| `IDIR`, `BCeID`, `Username`, `Password` | `Credentials` | `Protected B` |
| `CreditCard`, `CardNumber`, `CVV` | `Credit Card` | `Protected B` |
| `Amount`, `Payment`, `Invoice`, `Tax`, `Salary` | `Financial` | `Protected B` |
| `IPAddress`, `MACAddress` | `Networking` | `Protected A` |
| `Passport`, `DriversLicense`, `LicenseNumber` | `Identification` | `Protected A` |
| `Gender`, `Race`, `Indigeneity`, `Disability`, `Ability` | `Personal` | `Protected A` |
| `Comment`, `Note`, `Description`, `Memo` | `Free-form Text` | Review content; do not auto-label |
| `RegionCode`, `ProductCode`, `StatusCode` | `Other` | `Public` only if confirmed |

For every draft, state the evidence, confidence, uncertainty, and question.
Do not sample live values in Phase 1. A future Raven-backed provider may add
sampling only under an explicit privacy-safe capability contract.

## Deployment and output

Native classification scripts belong in project-local post-deployment
scripts, for example:

```text
Scripts\Post-Deployment\DataClassification\
    Dimension.Customer.Classification.sql
    Fact.Payment.Classification.sql
```

The Crow package must not contain project names, server names, credentials,
private paths, or generated customer classifications. Report whether output is
an uncommitted draft, a generated script, or an applied local change.

## References

- Microsoft Learn: `ADD SENSITIVITY CLASSIFICATION`
- Microsoft Learn: `sys.sensitivity_classifications`
- `modules/extended-properties.md` for table-level and non-column metadata
- The target organization's approved information-classification policy
