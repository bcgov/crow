# Unicode and UTF-8 Development

Apply this module whenever code reads, writes, validates, compares, searches, serializes, stores, exports, imports, or renders text.

## Implementation rules

- Use Unicode-native string APIs and UTF-8 for interchange/files unless the protocol explicitly requires another encoding.
- Set and test explicit UTF-8 charsets for HTTP/text responses, files, web servers, CSV, email, and batch interfaces where defaults are not guaranteed.
- Decode strictly at trust boundaries. Surface malformed encoding as an error rather than silently substituting replacement characters.
- Preserve original user text. Do not strip diacritics, transliterate, force ASCII, or normalize destructively to satisfy a downstream limitation.
- If equality/search needs canonical equivalence, create an explicitly documented normalized comparison/search value while preserving the original. Apply the same normalization consistently on both sides.
- Use grapheme-aware APIs for user-visible length limits, truncation, cursor movement, initials, and substring operations.
- Use explicit comparisons: ordinal for identifiers/protocol/security values; approved culture/collation for linguistic text.
- Validate database schema, driver parameters, literals, imports, exports, queues, caches, integrations, reporting, and fonts rather than assuming language-level Unicode strings are sufficient.
- Keep logs and telemetry UTF-8 capable, but continue to minimize and redact personal information.

## Test corpus and round trips

Maintain a small approved multilingual corpus that includes:

- Indigenous names using combining marks, such as a base Latin character plus U+0313;
- Unified Canadian Aboriginal Syllabics;
- canonically equivalent composed/decomposed sequences;
- supplementary-plane characters represented by surrogate pairs in UTF-16 runtimes;
- mixed-direction or invisible controls for security-policy tests, without treating them as ordinary name fixtures.

Test the actual end-to-end path: UI/API input -> application -> persistence -> retrieval/search -> API/message -> export/report/rendering. Assert exact code-point preservation where no documented transformation is intended.

## Sources

- Unicode Standard Annex #15, [Unicode Normalization Forms](https://unicode.org/reports/tr15/)
- B.C. Government, [Including Indigenous languages in government records, systems and services](https://www2.gov.bc.ca/gov/content/data/initiatives/including-indigenous-languages)
