# External analytics references

Use these as links to authoritative or primary material. Do not copy their
examples or reference documents into Crow. Select only sources relevant to
the confirmed technology and design question; external material does not
replace project evidence or user decisions.

- [Kimball Group: Dimensional Modeling Techniques](https://www.kimballgroup.com/data-warehouse-business-intelligence-resources/kimball-techniques/dimensional-modeling-techniques/)
- [Microsoft Learn: Understand star schema and the importance for Power BI](https://learn.microsoft.com/power-bi/guidance/star-schema)
- [Microsoft Learn: Tabular models in Analysis Services](https://learn.microsoft.com/analysis-services/tabular-models/tabular-models-ssas?view=asallproducts-allversions)
- [SQLBI: DAX Patterns](https://www.daxpatterns.com/)
- [Microsoft Learn: Paginated reports in Power BI](https://learn.microsoft.com/power-bi/paginated-reports/paginated-reports-report-builder-power-bi)

For engine-specific warehouse design and physical capabilities, consult the
documentation for the confirmed database and version:

- Oracle: [Data Warehousing Logical Design](https://docs.oracle.com/en/database/oracle/oracle-database/19/dwhsg/data-warehouse-logical-design.html)
  and [Dimensions](https://docs.oracle.com/en/database/oracle/oracle-database/19/dwhsg/dimensions.html)
  in the Oracle Database 19c Data Warehousing Guide.
- MySQL: [Partitioning](https://dev.mysql.com/doc/refman/8.4/en/partitioning.html) in the MySQL 8.4 Reference Manual.
- PostgreSQL: [Table Partitioning](https://www.postgresql.org/docs/current/ddl-partitioning.html) in the PostgreSQL documentation.

These engine references complement, but do not replace, dimensional modeling
guidance. Confirm the target database version before applying version-specific
features or constraints.

Do not assume SQL Server, SSAS, Power BI, a particular dimensional convention,
or an organization's deployment practices. Confirm technology and applicable
project standards before applying technology-specific guidance. When
classifications are in scope, use Crow's existing
[`crow-data-architecture` metadata governance](../../crow-data-architecture/modules/metadata-governance.md);
do not infer classifications or treat labels as access controls.
