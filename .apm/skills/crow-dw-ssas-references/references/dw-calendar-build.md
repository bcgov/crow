<!-- Crow portability note: migrated reference guidance; validate project-specific conventions and treat paths, versions, and platform choices as examples unless local evidence confirms them. -->

# DW Calendar Dimension Build Reference

Reference scripts for `Dimension.Calendar`, `Dimension.StatHolidays`, and the
`SSAS.v_Calendar` view. This is a **one-time build** (idempotent — safe to re-run).

**Design basis:** Adapted from the existing `dbo.Calendar` / `dbo.[LoadCalendar]` / `dbo.stat_holiday`
objects in the OLTP database.

| Aspect | OLTP (`dbo.Calendar`) | DW (`Dimension.Calendar`) |
|---|---|---|
| Primary key type | `DATE` (`DateKey DATE`) | `DATE` (`[Date Key] DATE`) — matches OLTP |
| Integer date surrogate | `YYYYMMDD` implicit in int columns | `[YYYYMMDD] INT` separate column; `[YYYYMM] CHAR(6)` |
| Unknown/sentinel rows | `'1753-01-01'` (min) / `'9999-12-31'` (max) | `'1753-01-01'` (unknown); `'9999-12-31'` (open/future) — matches OLTP |
| Fact table FK type | `DATE` | `DATE` — FK columns match Calendar PK |
| Open event sentinel | `EndDate = '9999-12-31'` | `[End Date Key] = '9999-12-31'` |
| Load approach | `WHILE` loop (row-by-row) | Recursive CTE (set-based — 10–100× faster) |
| Column naming | camelCase / no spaces | Title Case with spaces — SSAS/Kimball convention |
| StatHolidays | `dbo.stat_holiday` (BC + audit cols) | `Dimension.StatHolidays` (simplified — no audit cols) |

**Fiscal year convention (org standard — confirmed from `dbo.LoadCalendar`):**
- Fiscal year = **starting** calendar year: **FY2024 = Apr 1, 2024 – Mar 31, 2025**
- `Fiscal Year = CASE WHEN MONTH >= 4 THEN YEAR ELSE YEAR - 1 END`
- Fiscal Period 1 = April, Fiscal Period 12 = March
- Week numbering: Sunday-start (`DATEFIRST 7`)

**Fact table date FK columns:** Because `[Date Key]` is `DATE`, all fact table date FK
columns (e.g., `[Date Key]`, `[Order Date Key]`, `[Ship Date Key]`) must also be `DATE NOT NULL`
— no NULLs permitted. Use `'1753-01-01'` as the sentinel for unknown/inapplicable dates
(matches OLTP convention) and `'9999-12-31'` for open/no-end events.

---

## 1. Dimension.StatHolidays Table

Stat holiday data is produced by the Nager.Date C# project (see Section 6 for
update notes). The project outputs a SQL `MERGE` script targeting this table.

```sql
IF NOT EXISTS (
    SELECT 1 FROM sys.tables t
    JOIN sys.schemas s ON t.schema_id = s.schema_id
    WHERE s.name = 'Dimension' AND t.name = 'StatHolidays'
)
BEGIN
    CREATE TABLE [Dimension].[StatHolidays] (
        [Stat Holiday Key]  INT           NOT NULL IDENTITY(1, 1),
        [Stat Holiday Date] DATE          NOT NULL,
        [Stat Holiday Name] NVARCHAR(200) NOT NULL,
        CONSTRAINT [PK_Dimension_StatHolidays]
            PRIMARY KEY CLUSTERED ([Stat Holiday Key]),
        CONSTRAINT [UQ_Dimension_StatHolidays_Date]
            UNIQUE NONCLUSTERED ([Stat Holiday Date])
    );
END
```

> **Note:** No separate `[Stat Holiday Date Key] INT` column. The table joins to
> `Dimension.Calendar` directly on `[Stat Holiday Date] = [Date Key]` (both `DATE`).
> BC holidays only — no Province Code column needed.

**Holiday generation — MERGE template** (output from updated StatHolidayGenerator):

```sql
MERGE [Dimension].[StatHolidays] AS [target]
USING (
    VALUES
        (CAST('2024-01-01' AS DATE), N'New Year''s Day'),
        (CAST('2024-02-19' AS DATE), N'Family Day'),
        (CAST('2024-03-29' AS DATE), N'Good Friday'),
        (CAST('2024-04-01' AS DATE), N'Easter Monday'),
        (CAST('2024-05-20' AS DATE), N'Victoria Day'),
        (CAST('2024-07-01' AS DATE), N'Canada Day'),
        (CAST('2024-08-05' AS DATE), N'BC Day'),
        (CAST('2024-09-02' AS DATE), N'Labour Day'),
        (CAST('2024-09-30' AS DATE), N'National Day for Truth and Reconciliation'),
        (CAST('2024-10-14' AS DATE), N'Thanksgiving Day'),
        (CAST('2024-11-11' AS DATE), N'Remembrance Day'),
        (CAST('2024-12-25' AS DATE), N'Christmas Day'),
        (CAST('2024-12-26' AS DATE), N'Boxing Day')
) AS [source] ([Stat Holiday Date], [Stat Holiday Name])
ON [target].[Stat Holiday Date] = [source].[Stat Holiday Date]
WHEN MATCHED THEN
    UPDATE SET [Stat Holiday Name] = [source].[Stat Holiday Name]
WHEN NOT MATCHED BY TARGET THEN
    INSERT ([Stat Holiday Date], [Stat Holiday Name])
    VALUES ([source].[Stat Holiday Date], [source].[Stat Holiday Name])
WHEN NOT MATCHED BY SOURCE THEN
    DELETE;
```

> **BC policy quirks:**
> - Easter Monday and Boxing Day are included even though they are not technically
>   BC statutory holidays — the org treats them as stats.
> - In-lieu: if a holiday falls on Saturday the prior Friday is the observed date;
>   if it falls on Sunday the following Monday is the observed date. The generator
>   outputs the *observed* date, not the actual date.

---

## 2. Dimension.Calendar Table

44 columns. `[Date Key]` is `DATE` (matches OLTP convention); integer representations
are available as `[YYYYMMDD]` (INT) and `[YYYYMM]` (CHAR(6)).

```sql
IF NOT EXISTS (
    SELECT 1 FROM sys.tables t
    JOIN sys.schemas s ON t.schema_id = s.schema_id
    WHERE s.name = 'Dimension' AND t.name = 'Calendar'
)
BEGIN
    CREATE TABLE [Dimension].[Calendar] (
        -- ── Primary key ───────────────────────────────────────────────────────────
        [Date Key]                  DATE         NOT NULL,

        -- ── Integer surrogate / integer date representations ──────────────────────
        [YYYYMMDD]                  INT          NOT NULL,  -- 20240415
        [YYYYMM]                    CHAR(6)      NOT NULL,  -- '202404'

        -- ── Standard calendar year/month/day ─────────────────────────────────────
        [Year]                      INT          NULL,
        [Quarter]                   INT          NULL,
        [Quarter Name]              CHAR(2)      NULL,   -- 'Q1'
        [Month]                     INT          NULL,
        [Month Name]                VARCHAR(9)   NULL,   -- 'April'
        [Month Name Short]          CHAR(3)      NULL,   -- 'Apr'
        [Month Name First Letter]   CHAR(1)      NULL,   -- 'A'
        [Month Year]                CHAR(8)      NULL,   -- 'Apr 2024'
        [Day]                       INT          NULL,
        [Day Of Week]               INT          NULL,   -- 1 = Sunday (DATEFIRST 7)
        [Weekday Name]              VARCHAR(9)   NULL,   -- 'Monday'
        [Weekday Name Short]        CHAR(3)      NULL,   -- 'Mon'
        [Weekday Name First Letter] CHAR(1)      NULL,   -- 'M'
        [Day Of Year]               INT          NULL,
        [Day Of Week In Month]      INT          NULL,   -- nth occurrence of weekday in month
        [Day Of Week In Year]       INT          NULL,   -- nth occurrence of weekday in year
        [Week Of Year]              INT          NULL,   -- ISO-like, Sunday-start
        [Week Of Month]             INT          NULL,
        [Is Weekday]                BIT          NULL,
        [Is Weekend]                BIT          NULL,

        -- ── Fiscal calendar (Apr–Mar, starting-year convention) ───────────────────
        [Fiscal Year]               INT          NULL,   -- FY2024 = Apr 2024 – Mar 2025
        [Fiscal Year Name]          CHAR(6)      NULL,   -- 'FY2024'
        [Fiscal Year Name Short]    CHAR(4)      NULL,   -- 'FY24'
        [Fiscal Quarter]            INT          NULL,   -- 1–4 (Apr=Q1)
        [Fiscal Quarter Name]       CHAR(2)      NULL,   -- 'Q1'
        [Fiscal Period]             INT          NULL,   -- 1–12 (Apr=1, Mar=12)
        [Fiscal Period Name]        VARCHAR(9)   NULL,   -- 'Period 1'

        -- ── Period boundary dates ─────────────────────────────────────────────────
        [First Date Of Month]       DATE         NULL,
        [Last Date Of Month]        DATE         NULL,
        [First Date Of Quarter]     DATE         NULL,
        [Last Date Of Quarter]      DATE         NULL,
        [First Date Of Year]        DATE         NULL,
        [Last Date Of Year]         DATE         NULL,
        [First Date Of Fiscal Year] DATE         NULL,
        [Last Date Of Fiscal Year]  DATE         NULL,

        -- ── Calendar enrichment ───────────────────────────────────────────────────
        [Is Leap Year]              BIT          NULL,
        [Days In Month]             INT          NULL,
        [Is Stat Holiday]           BIT          NULL,
        [Stat Holiday Name]         NVARCHAR(200) NULL,
        [Is Pay Week]               BIT          NULL,   -- biweekly from 2000-01-01

        CONSTRAINT [PK_Dimension_Calendar]
            PRIMARY KEY CLUSTERED ([Date Key] ASC)
    );
END
```

> **Unknown / sentinel rows:**
> | Row | `[Date Key]` | Purpose |
> |-----|-------------|---------|
> | Unknown | `'1753-01-01'` | FK target when source date is NULL or unknown — matches OLTP min sentinel |
> | Open/future | `'9999-12-31'` | FK target for events with no end date (SCD Type 2, open subscriptions, etc.) |
>
> These rows are inserted by `Dimension.PopulateCalendar` before the main date range.
> **They live in `Dimension.Calendar` only (SQL FK constraint integrity). `SSAS.v_Calendar` filters them
> out so SSAS sees a contiguous date range — required for `Mark as Date Table` and DAX time intelligence.
> See Section 4 (view definition) and Section 5 (SSAS configuration) for details.**

---

## 3. Dimension.PopulateCalendar Stored Procedure

```sql
CREATE OR ALTER PROCEDURE [Dimension].[PopulateCalendar]
AS
BEGIN
    SET NOCOUNT ON;
    SET DATEFIRST 7;   -- Sunday = 1

    -- ── Sentinel / unknown member rows ──────────────────────────────────────────
    MERGE [Dimension].[Calendar] AS [target]
    USING (
        VALUES
            (CAST('1753-01-01' AS DATE), 17530101, '175301'),  -- unknown (matches OLTP min sentinel)
            (CAST('9999-12-31' AS DATE), 99991231, '999912')   -- open/future
    ) AS [source] ([Date Key], [YYYYMMDD], [YYYYMM])
    ON [target].[Date Key] = [source].[Date Key]
    WHEN NOT MATCHED BY TARGET THEN
        INSERT ([Date Key], [YYYYMMDD], [YYYYMM],
                [Year], [Quarter], [Quarter Name], [Month],
                [Month Name], [Month Name Short], [Month Name First Letter],
                [Month Year], [Day], [Day Of Week],
                [Weekday Name], [Weekday Name Short], [Weekday Name First Letter],
                [Day Of Year], [Day Of Week In Month], [Day Of Week In Year],
                [Week Of Year], [Week Of Month],
                [Is Weekday], [Is Weekend],
                [Fiscal Year], [Fiscal Year Name], [Fiscal Year Name Short],
                [Fiscal Quarter], [Fiscal Quarter Name],
                [Fiscal Period], [Fiscal Period Name],
                [First Date Of Month], [Last Date Of Month],
                [First Date Of Quarter], [Last Date Of Quarter],
                [First Date Of Year], [Last Date Of Year],
                [First Date Of Fiscal Year], [Last Date Of Fiscal Year],
                [Is Leap Year], [Days In Month],
                [Is Stat Holiday], [Stat Holiday Name], [Is Pay Week])
        VALUES (
            [source].[Date Key],
            [source].[YYYYMMDD], [source].[YYYYMM],
            NULL, NULL, NULL, NULL, NULL, NULL, NULL,
            NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
            NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
            NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
            NULL, NULL, NULL, NULL, NULL, NULL
        );

    -- ── Main date range: 2000-01-01 through 2050-12-31 ─────────────────────────
    ;WITH [DateSpine] AS (
        SELECT CAST('2000-01-01' AS DATE) AS [d]
        UNION ALL
        SELECT DATEADD(DAY, 1, [d])
        FROM [DateSpine]
        WHERE [d] < '2050-12-31'
    )
    MERGE [Dimension].[Calendar] AS [target]
    USING (
        SELECT
            -- ── Keys & integer representations ───────────────────────────────────
            [d]                                                             AS [Date Key],
            YEAR([d]) * 10000 + MONTH([d]) * 100 + DAY([d])               AS [YYYYMMDD],
            CAST(YEAR([d]) * 100 + MONTH([d]) AS CHAR(6))                  AS [YYYYMM],

            -- ── Calendar year / month / day ───────────────────────────────────────
            YEAR([d])                                                       AS [Year],
            DATEPART(QUARTER, [d])                                          AS [Quarter],
            'Q' + CAST(DATEPART(QUARTER, [d]) AS CHAR(1))                  AS [Quarter Name],
            MONTH([d])                                                      AS [Month],
            DATENAME(MONTH, [d])                                            AS [Month Name],
            LEFT(DATENAME(MONTH, [d]), 3)                                   AS [Month Name Short],
            LEFT(DATENAME(MONTH, [d]), 1)                                   AS [Month Name First Letter],
            LEFT(DATENAME(MONTH, [d]), 3) + ' ' + CAST(YEAR([d]) AS VARCHAR(4)) AS [Month Year],
            DAY([d])                                                        AS [Day],
            DATEPART(WEEKDAY, [d])                                          AS [Day Of Week],
            DATENAME(WEEKDAY, [d])                                          AS [Weekday Name],
            LEFT(DATENAME(WEEKDAY, [d]), 3)                                 AS [Weekday Name Short],
            LEFT(DATENAME(WEEKDAY, [d]), 1)                                 AS [Weekday Name First Letter],
            DATEPART(DAYOFYEAR, [d])                                        AS [Day Of Year],
            -- nth occurrence of this weekday within the month
            (DAY([d]) - 1) / 7 + 1                                         AS [Day Of Week In Month],
            -- nth occurrence of this weekday within the year
            (DATEPART(DAYOFYEAR, [d]) - 1) / 7 + 1                        AS [Day Of Week In Year],
            DATEPART(WEEK, [d])                                             AS [Week Of Year],
            -- week within month (Sunday-anchored)
            DATEDIFF(WEEK,
                DATEADD(DAY, 1 - DAY([d]), [d]),
                [d]) + 1                                                    AS [Week Of Month],
            CASE WHEN DATEPART(WEEKDAY, [d]) BETWEEN 2 AND 6 THEN 1 ELSE 0 END AS [Is Weekday],
            CASE WHEN DATEPART(WEEKDAY, [d]) IN (1, 7)        THEN 1 ELSE 0 END AS [Is Weekend],

            -- ── Fiscal calendar (Apr–Mar, starting-year convention) ───────────────
            -- FY2024 = Apr 1 2024 – Mar 31 2025
            CASE WHEN MONTH([d]) >= 4 THEN YEAR([d]) ELSE YEAR([d]) - 1 END AS [Fiscal Year],
            'FY' + CAST(CASE WHEN MONTH([d]) >= 4 THEN YEAR([d]) ELSE YEAR([d]) - 1 END AS VARCHAR(4))
                                                                            AS [Fiscal Year Name],
            'FY' + RIGHT(CAST(CASE WHEN MONTH([d]) >= 4 THEN YEAR([d]) ELSE YEAR([d]) - 1 END AS VARCHAR(4)), 2)
                                                                            AS [Fiscal Year Name Short],
            -- Fiscal Quarter: Apr-Jun=Q1, Jul-Sep=Q2, Oct-Dec=Q3, Jan-Mar=Q4
            CASE
                WHEN MONTH([d]) IN (4,5,6)   THEN 1
                WHEN MONTH([d]) IN (7,8,9)   THEN 2
                WHEN MONTH([d]) IN (10,11,12) THEN 3
                ELSE 4
            END                                                             AS [Fiscal Quarter],
            'Q' + CAST(CASE
                WHEN MONTH([d]) IN (4,5,6)   THEN 1
                WHEN MONTH([d]) IN (7,8,9)   THEN 2
                WHEN MONTH([d]) IN (10,11,12) THEN 3
                ELSE 4
            END AS CHAR(1))                                                 AS [Fiscal Quarter Name],
            -- Fiscal Period: Apr=1 … Mar=12
            CASE WHEN MONTH([d]) >= 4 THEN MONTH([d]) - 3 ELSE MONTH([d]) + 9 END
                                                                            AS [Fiscal Period],
            'Period ' + CAST(
                CASE WHEN MONTH([d]) >= 4 THEN MONTH([d]) - 3 ELSE MONTH([d]) + 9 END
            AS VARCHAR(2))                                                  AS [Fiscal Period Name],

            -- ── Period boundary dates ─────────────────────────────────────────────
            CAST(DATEFROMPARTS(YEAR([d]), MONTH([d]), 1) AS DATE)           AS [First Date Of Month],
            CAST(EOMONTH([d]) AS DATE)                                      AS [Last Date Of Month],
            CAST(DATEADD(QUARTER, DATEDIFF(QUARTER, 0, [d]), 0) AS DATE)    AS [First Date Of Quarter],
            CAST(DATEADD(DAY, -1,
                DATEADD(QUARTER, DATEDIFF(QUARTER, 0, [d]) + 1, 0)) AS DATE) AS [Last Date Of Quarter],
            CAST(DATEFROMPARTS(YEAR([d]), 1, 1) AS DATE)                    AS [First Date Of Year],
            CAST(DATEFROMPARTS(YEAR([d]), 12, 31) AS DATE)                  AS [Last Date Of Year],
            -- Fiscal year boundaries
            CAST(DATEFROMPARTS(
                CASE WHEN MONTH([d]) >= 4 THEN YEAR([d]) ELSE YEAR([d]) - 1 END,
                4, 1) AS DATE)                                              AS [First Date Of Fiscal Year],
            CAST(DATEFROMPARTS(
                CASE WHEN MONTH([d]) >= 4 THEN YEAR([d]) + 1 ELSE YEAR([d]) END,
                3, 31) AS DATE)                                             AS [Last Date Of Fiscal Year],

            -- ── Calendar enrichment ───────────────────────────────────────────────
            CASE WHEN DAY(EOMONTH(DATEFROMPARTS(YEAR([d]), 2, 1))) = 29
                 THEN 1 ELSE 0 END                                          AS [Is Leap Year],
            DAY(EOMONTH([d]))                                               AS [Days In Month],
            -- Is Pay Week: biweekly Thursday payroll, rooted at 2000-01-01
            CASE WHEN DATEDIFF(DAY, '2000-01-01', [d]) / 7 % 2 = 0
                 THEN 1 ELSE 0 END                                          AS [Is Pay Week]

        FROM [DateSpine]
    ) AS [source] ON [target].[Date Key] = [source].[Date Key]
    WHEN MATCHED THEN UPDATE SET
        [YYYYMMDD]                  = [source].[YYYYMMDD],
        [YYYYMM]                    = [source].[YYYYMM],
        [Year]                      = [source].[Year],
        [Quarter]                   = [source].[Quarter],
        [Quarter Name]              = [source].[Quarter Name],
        [Month]                     = [source].[Month],
        [Month Name]                = [source].[Month Name],
        [Month Name Short]          = [source].[Month Name Short],
        [Month Name First Letter]   = [source].[Month Name First Letter],
        [Month Year]                = [source].[Month Year],
        [Day]                       = [source].[Day],
        [Day Of Week]               = [source].[Day Of Week],
        [Weekday Name]              = [source].[Weekday Name],
        [Weekday Name Short]        = [source].[Weekday Name Short],
        [Weekday Name First Letter] = [source].[Weekday Name First Letter],
        [Day Of Year]               = [source].[Day Of Year],
        [Day Of Week In Month]      = [source].[Day Of Week In Month],
        [Day Of Week In Year]       = [source].[Day Of Week In Year],
        [Week Of Year]              = [source].[Week Of Year],
        [Week Of Month]             = [source].[Week Of Month],
        [Is Weekday]                = [source].[Is Weekday],
        [Is Weekend]                = [source].[Is Weekend],
        [Fiscal Year]               = [source].[Fiscal Year],
        [Fiscal Year Name]          = [source].[Fiscal Year Name],
        [Fiscal Year Name Short]    = [source].[Fiscal Year Name Short],
        [Fiscal Quarter]            = [source].[Fiscal Quarter],
        [Fiscal Quarter Name]       = [source].[Fiscal Quarter Name],
        [Fiscal Period]             = [source].[Fiscal Period],
        [Fiscal Period Name]        = [source].[Fiscal Period Name],
        [First Date Of Month]       = [source].[First Date Of Month],
        [Last Date Of Month]        = [source].[Last Date Of Month],
        [First Date Of Quarter]     = [source].[First Date Of Quarter],
        [Last Date Of Quarter]      = [source].[Last Date Of Quarter],
        [First Date Of Year]        = [source].[First Date Of Year],
        [Last Date Of Year]         = [source].[Last Date Of Year],
        [First Date Of Fiscal Year] = [source].[First Date Of Fiscal Year],
        [Last Date Of Fiscal Year]  = [source].[Last Date Of Fiscal Year],
        [Is Leap Year]              = [source].[Is Leap Year],
        [Days In Month]             = [source].[Days In Month],
        [Is Pay Week]               = [source].[Is Pay Week]
    WHEN NOT MATCHED BY TARGET THEN
        INSERT ([Date Key], [YYYYMMDD], [YYYYMM],
                [Year], [Quarter], [Quarter Name],
                [Month], [Month Name], [Month Name Short],
                [Month Name First Letter], [Month Year],
                [Day], [Day Of Week], [Weekday Name], [Weekday Name Short],
                [Weekday Name First Letter], [Day Of Year],
                [Day Of Week In Month], [Day Of Week In Year],
                [Week Of Year], [Week Of Month],
                [Is Weekday], [Is Weekend],
                [Fiscal Year], [Fiscal Year Name], [Fiscal Year Name Short],
                [Fiscal Quarter], [Fiscal Quarter Name],
                [Fiscal Period], [Fiscal Period Name],
                [First Date Of Month], [Last Date Of Month],
                [First Date Of Quarter], [Last Date Of Quarter],
                [First Date Of Year], [Last Date Of Year],
                [First Date Of Fiscal Year], [Last Date Of Fiscal Year],
                [Is Leap Year], [Days In Month], [Is Pay Week])
        VALUES (
            [source].[Date Key], [source].[YYYYMMDD], [source].[YYYYMM],
            [source].[Year], [source].[Quarter], [source].[Quarter Name],
            [source].[Month], [source].[Month Name], [source].[Month Name Short],
            [source].[Month Name First Letter], [source].[Month Year],
            [source].[Day], [source].[Day Of Week], [source].[Weekday Name],
            [source].[Weekday Name Short], [source].[Weekday Name First Letter],
            [source].[Day Of Year], [source].[Day Of Week In Month],
            [source].[Day Of Week In Year], [source].[Week Of Year],
            [source].[Week Of Month], [source].[Is Weekday], [source].[Is Weekend],
            [source].[Fiscal Year], [source].[Fiscal Year Name],
            [source].[Fiscal Year Name Short], [source].[Fiscal Quarter],
            [source].[Fiscal Quarter Name], [source].[Fiscal Period],
            [source].[Fiscal Period Name],
            [source].[First Date Of Month], [source].[Last Date Of Month],
            [source].[First Date Of Quarter], [source].[Last Date Of Quarter],
            [source].[First Date Of Year], [source].[Last Date Of Year],
            [source].[First Date Of Fiscal Year], [source].[Last Date Of Fiscal Year],
            [source].[Is Leap Year], [source].[Days In Month], [source].[Is Pay Week]
        )
    OPTION (MAXRECURSION 0);   -- CTE generates 18,628 rows; exceeds default limit of 100

    -- ── Overlay stat holidays (after main population) ───────────────────────────
    UPDATE c
    SET
        [Is Stat Holiday]  = 1,
        [Stat Holiday Name] = h.[Stat Holiday Name]
    FROM [Dimension].[Calendar] c
    JOIN [Dimension].[StatHolidays] h
        ON h.[Stat Holiday Date] = c.[Date Key];

    -- Clear any removed holidays
    UPDATE c
    SET
        [Is Stat Holiday]  = 0,
        [Stat Holiday Name] = NULL
    FROM [Dimension].[Calendar] c
    WHERE c.[Date Key] > '1753-01-01'
      AND c.[Date Key] < '9999-12-31'
      AND c.[Is Stat Holiday] = 1
      AND NOT EXISTS (
          SELECT 1 FROM [Dimension].[StatHolidays] h
          WHERE h.[Stat Holiday Date] = c.[Date Key]
      );
END
```

> **Re-run safety:** The MERGE handles `WHEN MATCHED` so re-running after a holiday
> table update is safe. Stat holiday clear-up only touches the main date range,
> never the sentinel rows.

---

## 4. SSAS.v_Calendar View

This view adds volatile/relative columns that depend on `GETDATE()`. Keeping these
in the view (rather than the base table) avoids daily updates to `Dimension.Calendar`.

```sql
CREATE OR ALTER VIEW [SSAS].[v_Calendar]
AS
    SELECT
        -- ── Passthrough from Dimension.Calendar ───────────────────────────────────
        c.[Date Key],
        c.[YYYYMMDD],
        c.[YYYYMM],
        c.[Year],
        c.[Quarter],
        c.[Quarter Name],
        c.[Month],
        c.[Month Name],
        c.[Month Name Short],
        c.[Month Name First Letter],
        c.[Month Year],
        c.[Day],
        c.[Day Of Week],
        c.[Weekday Name],
        c.[Weekday Name Short],
        c.[Weekday Name First Letter],
        c.[Day Of Year],
        c.[Day Of Week In Month],
        c.[Day Of Week In Year],
        c.[Week Of Year],
        c.[Week Of Month],
        c.[Is Weekday],
        c.[Is Weekend],
        c.[Fiscal Year],
        c.[Fiscal Year Name],
        c.[Fiscal Year Name Short],
        c.[Fiscal Quarter],
        c.[Fiscal Quarter Name],
        c.[Fiscal Period],
        c.[Fiscal Period Name],
        c.[First Date Of Month],
        c.[Last Date Of Month],
        c.[First Date Of Quarter],
        c.[Last Date Of Quarter],
        c.[First Date Of Year],
        c.[Last Date Of Year],
        c.[First Date Of Fiscal Year],
        c.[Last Date Of Fiscal Year],
        c.[Is Leap Year],
        c.[Days In Month],
        c.[Is Stat Holiday],
        c.[Stat Holiday Name],
        c.[Is Pay Week],

        -- ── Relative / current-date columns (volatile — computed from GETDATE()) ──
        CASE WHEN c.[Date Key] = CAST(GETDATE() AS DATE) THEN 1 ELSE 0 END
                                                                AS [Is Today],
        CASE WHEN c.[YYYYMM] = CAST(YEAR(GETDATE()) * 100 + MONTH(GETDATE()) AS CHAR(6))
             THEN 1 ELSE 0 END                                  AS [Is Current Month],
        CASE WHEN c.[Fiscal Year] =
                    CASE WHEN MONTH(GETDATE()) >= 4
                         THEN YEAR(GETDATE())
                         ELSE YEAR(GETDATE()) - 1 END
             THEN 1 ELSE 0 END                                  AS [Is Current Fiscal Year],
        DATEDIFF(DAY, c.[Date Key], CAST(GETDATE() AS DATE))    AS [Relative Day],
        DATEDIFF(WEEK, c.[Date Key], CAST(GETDATE() AS DATE))   AS [Relative Week],
        DATEDIFF(MONTH, c.[Date Key], CAST(GETDATE() AS DATE))  AS [Relative Month]

    FROM [Dimension].[Calendar] c
    WHERE c.[Date Key] > '1753-01-01'   -- exclude unknown sentinel
      AND c.[Date Key] < '9999-12-31';  -- exclude open/future sentinel
GO
```

> **Sentinel row exclusion:** The view filters out both sentinel rows so SSAS only
> sees real dates. Reference the sentinels directly from `Dimension.Calendar` in ELT
> fact-load queries (e.g., `ISNULL([source].[OrderDate], '1753-01-01')` for unknown
> dates, `CAST('9999-12-31' AS DATE)` for open SCD Type 2 rows).

---

## 5. SSAS Tabular Configuration

### Date table declaration

After importing `SSAS.v_Calendar`, mark it as a Date table:

**Option A — SSDT / Visual Studio:**
1. Open the SSAS project, select the `Calendar` table in the model diagram
2. Table menu → *Mark as Date Table* → *Mark as Date Table…*
3. Set *Date Column* to `[Date Key]` (type must show `Date` — ✓)
4. Click *OK*. SSAS validates the column is unique and has no NULLs.

**Option B — Tabular Editor 2:**
1. Select the `Calendar` table in the object tree
2. Properties pane → `DataCategory` → set to `Time`
3. Right-click `[Date Key]` column → *Mark as Date Key*
   (or set `IsKey = true` and `DataCategory = "Time"` in Properties)

**TMDL (git-tracked JSON):**
```json
"dateColumn": "Date Key"
```
This line in the Calendar table TMDL JSON controls `Mark as Date Table`.

```
Mark as Date Table → Date Column: [Date Key]   (DATA TYPE must be Date — ✓)
```

`[Date Key]` is `DATE` type — SQL Server Analysis Services accepts `DATE` columns
directly as the date table key. No conversion needed.

> **Contiguity validation:** Before deploying, run this DMV query against the SSAS instance to verify no gaps:
> ```sql
> SELECT COUNT(*) AS CalendarRows,
>        MIN([Date Key]) AS MinDate,
>        MAX([Date Key]) AS MaxDate,
>        DATEDIFF(DAY, MIN([Date Key]), MAX([Date Key])) + 1 AS ExpectedRows
> FROM $System.DISCOVER_STORAGE_TABLE_COLUMNS  -- use SSAS DMV or query model view
> ```
> Simpler approach — query the view directly:
> ```sql
> SELECT COUNT(*) AS ActualRows,
>        DATEDIFF(DAY, MIN([Date Key]), MAX([Date Key])) + 1 AS ExpectedRows
> FROM [SSAS].[v_Calendar];
> -- ActualRows must = ExpectedRows (no gaps, no sentinels, no duplicates)
> ```

### Sort-by columns

| Column | Sort By |
|---|---|
| `[Month Name]` | `[Month]` |
| `[Month Name Short]` | `[Month]` |
| `[Month Year]` | `[YYYYMM]` |
| `[Weekday Name]` | `[Day Of Week]` |
| `[Weekday Name Short]` | `[Day Of Week]` |
| `[Fiscal Period Name]` | `[Fiscal Period]` |
| `[Fiscal Quarter Name]` | `[Fiscal Quarter]` |
| `[Fiscal Year Name]` | `[Fiscal Year]` |
| `[Fiscal Year Name Short]` | `[Fiscal Year]` |
| `[Quarter Name]` | `[Quarter]` |

### Hidden columns (numeric keys used for sort-by only)

`[Month]`, `[Quarter]`, `[Day Of Week]`, `[Day Of Year]`, `[Week Of Year]`,
`[Day Of Week In Month]`, `[Day Of Week In Year]`, `[Week Of Month]`,
`[Fiscal Period]`, `[Fiscal Quarter]`, `[Fiscal Year]`,
`[YYYYMMDD]`, `[YYYYMM]`, `[Relative Day]`, `[Relative Week]`, `[Relative Month]`

> **`[YYYYMMDD]` is always populated (NOT NULL).** It is computed in the `LoadCalendar` procedure as `YEAR * 10000 + MONTH * 100 + DAY` for every calendar date — there is no scenario in which a valid calendar row would produce a NULL. It is hidden in SSAS because it has no user-facing meaning; its only purpose is as a compact integer representation for external integrations (e.g., flat file exports, legacy system keys).

> **Blank row behavior:** When `Mark as Date Table` is enabled on `Calendar`, SSAS suppresses the automatic blank row for the `Calendar` table. Fact rows that joined to the `1753-01-01` sentinel via the SQL FK will show `[Date Key] = 1753-01-01` in SSAS rather than a blank row. DAX measures should handle this explicitly if needed:
> ```dax
> -- Exclude unknown/sentinel dates from time intelligence totals
> Sales Excl Unknown :=
> CALCULATE( [Total Sales],
>     'Calendar'[Date Key] <> DATE(1753,1,1) )
> ```

### Display folders

| Folder | Columns |
|---|---|
| `Calendar\Year` | `[Year]`, `[Quarter]`, `[Quarter Name]`, `[Month]`, `[Month Name]`, `[Month Name Short]`, `[Month Year]`, `[Day]` |
| `Calendar\Week` | `[Week Of Year]`, `[Week Of Month]`, `[Day Of Week]`, `[Weekday Name]`, `[Weekday Name Short]` |
| `Calendar\Day Attributes` | `[Day Of Year]`, `[Day Of Week In Month]`, `[Day Of Week In Year]`, `[Is Weekday]`, `[Is Weekend]`, `[Is Leap Year]`, `[Days In Month]` |
| `Calendar\Period Boundaries` | `[First Date Of Month]`, `[Last Date Of Month]`, `[First Date Of Quarter]`, `[Last Date Of Quarter]`, `[First Date Of Year]`, `[Last Date Of Year]` |
| `Fiscal\Year` | `[Fiscal Year]`, `[Fiscal Year Name]`, `[Fiscal Year Name Short]`, `[Fiscal Quarter]`, `[Fiscal Quarter Name]`, `[Fiscal Period]`, `[Fiscal Period Name]` |
| `Fiscal\Period Boundaries` | `[First Date Of Fiscal Year]`, `[Last Date Of Fiscal Year]` |
| `Relative` | `[Is Today]`, `[Is Current Month]`, `[Is Current Fiscal Year]`, `[Relative Day]`, `[Relative Week]`, `[Relative Month]` |
| `Holidays & Payroll` | `[Is Stat Holiday]`, `[Stat Holiday Name]`, `[Is Pay Week]` |
| `Labels` | `[Month Name First Letter]`, `[Weekday Name First Letter]`, `[Month Name Short]`, `[Weekday Name Short]` |

### Time intelligence

Because `[Date Key]` is `DATE` type, standard SSAS time intelligence functions
(`DATEADD`, `DATESYTD`, `DATESQTD`, `DATESINPERIOD`, etc.) work without any
additional configuration.

---

## 6. StatHolidayGenerator Update Notes

The C# project at `src\dev\Database\StatHolidayGenerator` needs the following
changes before it can generate the full 2000–2050 range targeting `Dimension.StatHolidays`.

### Required changes

| Area | Current state | Required state |
|---|---|---|
| .NET target | .NET 6 | .NET 8 |
| Nager.Date version | 1.46.0 | 3.x |
| API class | `HolidayClient` (removed in v3) | `DateSystem` static class |
| Date range | 2023–2042 | 2000–2050 |
| Output path | Hardcoded `$(temp)\holidays.sql` | CLI argument `args[0]` |
| Target table | `[dbo].[stat_holiday]` | `[Dimension].[StatHolidays]` |
| Province filter | `countryCode = "CA"`, filter `provinceCode = "BC"` | `DateSystem.GetPublicHolidays(year, "CA")` then filter `Subdivisions.Contains("CA-BC")` |
| Easter Monday / Boxing Day | Custom additions | Still required — add manually if Nager omits them |
| In-lieu logic | Custom Saturday/Sunday → weekday shift | Keep as-is (already correct) |

### New API pattern (Nager.Date 3.x)

```csharp
using Nager.Date;

var holidays = DateSystem.GetPublicHolidays(year, "CA")
    .Where(h => h.SubdivisionCodes == null
             || h.SubdivisionCodes.Contains("CA-BC"))
    .OrderBy(h => h.Date)
    .ToList();
```

### MERGE target change

Output file header changes from:
```sql
MERGE [dbo].[stat_holiday] AS [target]
```
to:
```sql
MERGE [Dimension].[StatHolidays] AS [target]
USING (VALUES ...) AS [source] ([Stat Holiday Date], [Stat Holiday Name])
ON [target].[Stat Holiday Date] = [source].[Stat Holiday Date]
```

> Note: The join is now on `DATE` type. No integer date key column needed.

---

## 7. Fiscal Year Quick Reference

| Calendar months | Fiscal Year label | Fiscal Periods | Fiscal Quarters |
|---|---|---|---|
| Apr 2023 – Jun 2023 | FY2023 | P1–P3 | Q1 |
| Jul 2023 – Sep 2023 | FY2023 | P4–P6 | Q2 |
| Oct 2023 – Dec 2023 | FY2023 | P7–P9 | Q3 |
| Jan 2024 – Mar 2024 | FY2023 | P10–P12 | Q4 |
| Apr 2024 – Jun 2024 | FY2024 | P1–P3 | Q1 |
| Jul 2024 – Sep 2024 | FY2024 | P4–P6 | Q2 |
| Oct 2024 – Dec 2024 | FY2024 | P7–P9 | Q3 |
| Jan 2025 – Mar 2025 | FY2024 | P10–P12 | Q4 |

> FY2024 starts April 1, 2024 and ends March 31, 2025. Label = **starting** year.

---

## 8. Deployment Checklist

```
[ ] 1. Populate Dimension.StatHolidays first (MERGE from updated generator output)
[ ] 2. Execute Dimension.PopulateCalendar
[ ] 3. Validate row count: SELECT COUNT(*) FROM Dimension.Calendar  → expect 18,628 + 2 sentinels
[ ] 4. Verify sentinel rows present:
        SELECT [Date Key] FROM Dimension.Calendar
        WHERE [Date Key] IN ('1753-01-01', '9999-12-31')
[ ] 5. Spot-check fiscal year labels:
        SELECT [Date Key], [Fiscal Year], [Fiscal Year Name], [Fiscal Period]
        FROM Dimension.Calendar
        WHERE [Date Key] IN ('2024-03-31', '2024-04-01', '2025-03-31', '2025-04-01')
[ ] 6. Validate stat holidays:
        SELECT [Date Key], [Is Stat Holiday], [Stat Holiday Name]
        FROM Dimension.Calendar
        WHERE [Is Stat Holiday] = 1 AND YEAR([Date Key]) = 2024
        ORDER BY [Date Key]
[ ] 7. Validate pay weeks:
        SELECT TOP 10 [Date Key], [Is Pay Week] FROM Dimension.Calendar
        WHERE [Is Pay Week] = 1 ORDER BY [Date Key]
[ ] 8. Check YYYYMMDD and YYYYMM:
        SELECT [Date Key], [YYYYMMDD], [YYYYMM]
        FROM Dimension.Calendar
        WHERE [Date Key] IN ('2024-04-15', '2025-01-01')
[ ] 9. Import SSAS.v_Calendar into SSAS Tabular model
[ ] 10. Mark as Date Table → Date Column: [Date Key]
[ ] 11. Configure sort-by columns (see Section 5)
[ ] 12. Hide numeric key columns (see Section 5)
[ ] 13. Arrange into display folders (see Section 5)
[ ] 14. Verify time intelligence functions work in DAX (e.g., TOTALYTD, DATEADD)
```
