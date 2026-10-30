# Metadata Governance

Keep three metadata items with the schema itself so they travel with backups,
replicas, migrations, and catalogue tools:

| Item | Level | Canonical name | Source of truth |
| --- | --- | --- | --- |
| Description | Table and column | `MS_Description` | Data owner or analyst |
| Security classification | Column | `DataClassification` | Information owner, per the B.C. standard |
| Records schedule | Table or column, according to retention scope | `RecordsSchedule` | Records officer, per ARCS or ORCS |

The names match the bcgov/wwwsqldesigner exports, so metadata round-trips
between the designer, EF annotations, and SQL Server extended properties. Use
them unless the repository already has an established equivalent.

## B.C. information security classification

The Information Security Classification Standard (Office of the Chief
Information Officer, effective 31 October 2023) defines four levels by the
harm that unauthorized disclosure could reasonably be expected to cause:

| Value | Harm to an individual, organization, or government |
| --- | --- |
| `Public` | No harm |
| `Protected A` | Harm |
| `Protected B` | Serious harm |
| `Protected C` | Extremely grave harm |

- Use exactly these four values, spelled and capitalized as shown.
  "Confidential" is the standard's grouping heading for the three Protected
  levels, not a separate value.
- Classification depends on content **and** context. The same address can be
  Protected A on one list and Protected B or C elsewhere. Ask the information
  owner when context is unclear; never downgrade to make a design simpler.
- A table, schema, or system takes the highest classification of any column
  it holds. Derived columns, history, audit, and exports inherit the
  classification of their sources unless the owner approves otherwise.
- `Public` does not mean publishable. Release remains the information
  owner's decision.
- Owners may add labels such as "Cabinet Confidential" to restrict access
  further. Record them in the description; do not invent new classification
  values.
- Classification metadata documents sensitivity. It is not an access control,
  encryption, or masking mechanism, and it does not establish privacy
  authority.

Sources:
<https://www2.gov.bc.ca/assets/gov/government/services-for-government-and-broader-public-sector/information-technology-services/standards-files/618_information_security_classification_standard.pdf>
and the accompanying classification guidelines.

## Records schedules (ARCS and ORCS)

- The Information Management Act requires government information to be held
  and disposed of under an approved information schedule.
- ARCS (Administrative Records Classification System) covers administrative
  records common to government. An ORCS (Operational Records Classification
  System) covers a ministry's or program's operational records.
- Classifications use a primary-secondary number such as `100-20`. Schedules
  state active and semi-active retention periods and a final disposition,
  abbreviated in the schedules as `DE` (destruction), `FR` (full retention),
  `SR` (selective retention), or `OD` (other disposition), with triggers such
  as `CY` (calendar year), `FY` (fiscal year), or `SO` (superseded or
  obsolete).
- **Never invent or infer a schedule number, period, or disposition.** Use
  the values the records officer provides. If no value is available, leave
  the item empty and list it as an open decision.
- **Write the records schedule as a plain-text description** so a reader of
  the metadata never needs to look up a code. Use this form, with the
  schedule number only in the closing brackets for traceability:

  ```text
  <records class title>: <retention period and the event that starts it> (ARCS|ORCS <number>)
  ```

  - Required: the records class title (what the records are), and the
    retention period with the event that starts it. A final disposition and
    any semi-active period are optional; add them in words when known.
  - Spell out abbreviations: "destroy", not `DE`; "after the fiscal year
    ends", not `FY`; "until superseded or obsolete", not `SO`.
  - Examples (numbers and periods are illustrative, not real schedule
    entries):
    `Permit application files: retain 7 years after the permit is closed, then destroy (ORCS 12345-20)`
    and
    `Executive briefing notes: retain permanently and transfer to the Digital Archives (ARCS 100-20)`.
  - `Test-WwwSqlDesignerModel.ps1` rejects code-only values, missing
    brackets, abbreviations outside the brackets, and values without a
    retention period or starting event. It cannot confirm that the text
    matches the approved schedule; the records officer does.
- Do not compute destruction dates without the approved schedule and its
  trigger event. Design the columns the trigger needs (for example a closure
  date) and a disposition path that also covers history and derived copies.
- Put a schedule at the level whose data is governed by it. A table can
  contain columns with different retention periods; do not split the table
  just to make schedules uniform. Use field-level metadata plus a separately
  executable purge or de-identification path when an individual attribute
  expires before the rest of its record. Split or isolate data only when
  access, lifecycle, integrity, or operational needs justify the additional
  structure. For example, an approved schedule may require an identity-number
  column to be erased after a decision while the person's remaining record is
  retained under its own schedule.

Current schedules:
<https://www2.gov.bc.ca/gov/content/data/information-management/information-schedules>.

## Where each engine stores metadata

Prefer native structured metadata. Use the comment trailer only where the
engine has no structured equivalent.

| Engine | Description | Classification | Records schedule |
| --- | --- | --- | --- |
| SQL Server 2005+ / Azure SQL | Extended property `MS_Description` | Extended property `DataClassification`; on 2019+ and Azure SQL, optionally also `ADD SENSITIVITY CLASSIFICATION` | Extended property `RecordsSchedule` on the governed table or column |
| Oracle 23ai+ (also 19.28+) | `COMMENT ON` | Annotation `"DataClassification"` | Annotation `"RecordsSchedule"` on the governed table or column |
| Earlier Oracle | `COMMENT ON` with trailer | Trailer | Trailer |
| PostgreSQL | `COMMENT ON` with trailer | Trailer | Trailer |
| MySQL / MariaDB | `COMMENT` clause with trailer | Trailer | Trailer |

`New-DataModelMetadataSql.ps1` generates these statements from a validated
model. The engine modules list limits and catalogue queries.

## Comment trailer convention

When a comment must carry structured metadata, append one terminal block to
the human description:

```text
Legal name of the applicant. @bcgov{DataClassification=Protected B}
Permit applications submitted by the public. @bcgov{RecordsSchedule=Permit application files: retain 7 years after the permit is closed, then destroy (ORCS 12345-20)}
```

- The description comes first and the trailer follows it. Only an
  ORM-appended type hint, such as Doctrine DBAL 3 `(DC2Type:json)`, may follow
  the trailer.
- Keys are the canonical names above, separated by `;` and written as
  `key=value`.
- A column with a retention schedule that differs from its table's schedule
  can keep the plain-text schedule in the terminal column-comment trailer,
  for example
  `Social Insurance Number. @bcgov{RecordsSchedule=Identity verification data: retain until the decision is final, then destroy (ORCS 12345-20)}`.
  The table-level schedule continues to govern the record as a whole; record
  how a field-level purge or de-identification is performed without deleting
  the rest of the row. The wwwsqldesigner portable-v1 XML represents a
  column-level schedule with this trailer in the standard `<comment>` text,
  because its `<records-schedule>` element is table-only.
- Percent-encode `%`, `;`, `=`, `{`, and `}` in values as `%25`, `%3B`, `%3D`,
  `%7B`, and `%7D`.
- Parsers read the last `@bcgov{...}` block only. A human description must
  not contain `@bcgov{`, except for the recognized terminal
  `RecordsSchedule` trailer in a column comment; the validator rejects other
  marker uses.
- Keep the whole comment within the engine limit; MySQL column comments are
  the tightest at 1,024 characters.

## ORM placement

Keep metadata in the same migration as the schema change, so a column never
exists without its classification:

- EF Core: `HasComment` for descriptions; annotations or `migrationBuilder.Sql`
  for the other items (see the Entity Framework module).
- JPA: `comment` on `@Table` and `@Column` (Jakarta Persistence 3.2+), or
  Liquibase remarks or Flyway SQL.
- Doctrine and Eloquent: the `comment` option, plus raw SQL for structured
  metadata.

## Verification

- Every new or changed table has a description and records schedule, and
  every new or changed column has a description and classification, or the
  gap is listed as an owner decision.
- A column whose retention differs from its table has its own schedule and
  executable field-purge or de-identification plan, or an owner decision.
- Query the engine catalogue after migration in a test database to confirm
  the metadata exists and matches the model.
- Descriptions explain business meaning, units, and allowed values. Do not
  restate the column name, and do not include personal information, secrets,
  or internal hostnames.
- Database metadata does not replace catalogue records such as the BC Data
  Catalogue or the Core Metadata Standard; reference those processes when
  data is published.
