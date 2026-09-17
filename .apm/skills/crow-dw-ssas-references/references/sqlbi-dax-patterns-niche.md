<!-- Crow portability note: migrated reference guidance; validate project-specific conventions and treat paths, versions, and platform choices as examples unless local evidence confirms them. -->

# SQLBI DAX Patterns — Niche (Low Likelihood)

Patterns for specialised scenarios. Reference only when the specific scenario is confirmed present in the project.

---

## Currency Conversion

**Source:** https://www.daxpatterns.com/currency-conversion/
**Likelihood:** 🔵 Low — org likely operates in a single currency (on-premises, Australian context)

If multi-currency is required, two approaches exist: strong currency (convert in ETL before loading DW) or weak currency (convert in DAX at query time). Strong currency is preferred for on-premises SSAS Tabular due to performance.

### Strong currency pattern (preferred)
Convert to reporting currency in the `Staging.Load*` SP. Store converted amount in the fact table alongside original. No DAX needed.

### Weak currency pattern (DAX)
```dax
Converted Amount =
SUMX(
    'Fact SalesTransaction',
    'Fact SalesTransaction'[Amount]
        * LOOKUPVALUE(
            'ExchangeRate'[Rate],
            'ExchangeRate'[From Currency], 'Fact SalesTransaction'[Currency Code],
            'ExchangeRate'[To Currency], "AUD",  -- replace with org reporting currency
            'ExchangeRate'[Date Key], 'Fact SalesTransaction'[Date Key],
            0  -- default: no rate found = 0 (flag in data quality)
        )
)
```

---

## Survey and Basket Analysis

**Source:** https://www.daxpatterns.com/survey/ and https://www.daxpatterns.com/basket-analysis/
**Likelihood:** 🔵 Low — specialised; applicable to HR survey data or product co-purchase analysis

Survey pattern: analyses correlations between answers to different questions by the same respondent. Basket analysis: analyses which items frequently appear together in the same transaction.

Both patterns require a bridge table (covered in `kimball-patterns.md` → Bridge Table section) and are computationally expensive. Confirm with the user before implementing — these patterns may require dedicated SSAS partitioning strategy.

For implementation details, see: https://www.daxpatterns.com/survey/ and https://www.daxpatterns.com/basket-analysis/

---

## See Also

- `sqlbi-dax-patterns.md` — Core essential patterns
- `sqlbi-dax-patterns-advanced.md` — Medium-likelihood patterns
