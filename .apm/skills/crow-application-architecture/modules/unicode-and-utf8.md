# Unicode and UTF-8 Architecture

Load this module for every application. B.C. government systems must be able to receive, store, process, search, transmit, display, export, and print names and text containing Indigenous-language characters without corruption or loss.

## End-to-end readiness

Treat Unicode support as an end-to-end data-path property, not a UI-only setting. For every text-bearing path, verify:

1. browser/UI input and clipboard;
2. HTTP headers, request/response bodies, multipart uploads, and query parameters;
3. application strings, validation, parsing, serialization, queues, events, and caches;
4. database encoding, column types, literals, drivers, collation, indexes, search, and migrations;
5. integrations, files, object storage, ETL, analytics, reports, PDFs, labels, email, and printing;
6. logs and telemetry where text is intentionally retained;
7. fonts and rendering engines used by every output channel.

Use UTF-8 for interchange and persisted text formats unless a platform protocol mandates another Unicode encoding. Declare charset explicitly where protocols or file formats require it; do not rely on machine locale or implicit defaults.

## Data integrity and semantics

- Preserve the spelling and code points supplied by the person or authoritative source. Never transliterate, strip diacritics, replace unsupported characters, or force ASCII as a compatibility shortcut.
- Define a normalization policy only where canonical equivalence affects equality, uniqueness, search, or integration. Preserve the original value when normalization is needed for a comparison/search key.
- Count, truncate, cursor, and validate user-perceived characters by grapheme cluster where the behavior is presented to users. Code units, bytes, and Unicode scalar values are not interchangeable.
- Use ordinal comparison for protocol values, identifiers, and security decisions. Use an explicitly selected culture/collation for linguistic display, search, and sorting.
- Do not assume a default Unicode/CLDR collation matches a community's preferred alphabet or dictionary order. Treat language-specific sorting/search as a product and community consultation decision.
- Prevent visually confusable and bidirectional-control characters from weakening identifiers, authorization, filenames, audit records, or source/configuration review. Do not reject valid name text merely because those controls require stricter policy in identifiers.

## Storage and integration

- Verify database and column encodings/types with a round-trip test; a Unicode application string cannot prevent corruption in a non-Unicode column, literal, driver, import, or export.
- Treat collation changes as semantic and potentially index-affecting migrations. Plan validation, rollback, and duplicate/conflict handling.
- Version message and API contracts without narrowing text fields or silently normalizing values.
- Specify UTF-8 for CSV, JSON, XML, text exports, imports, and batch interfaces, including byte-order-mark policy where consumers require one.
- Reject or quarantine malformed input at the trust boundary with an explicit error; never replace invalid bytes silently.

## Runtime and deployment

- Ensure production images and hosts include the globalization data and fonts the application requires.
- Do not enable globalization-invariant modes for applications that perform culture-aware casing, comparison, sorting, formatting, or parsing.
- Minimal/chiseled/distroless images must be evaluated for ICU/CLDR, timezone, locale, and font availability rather than selected by size alone.

## Architecture evidence and acceptance

Document:

- the encoding and collation at every persisted/integration boundary;
- normalization and comparison policies;
- font/rendering dependencies;
- known downstream systems that cannot yet preserve Unicode;
- migration/compatibility plans for those gaps;
- tests covering representative Indigenous-language text, including combining marks and syllabics, across the complete round trip.

At minimum, tests must prove create, read, update, search, sort where applicable, API/message transit, export/import, and rendered output. Include decomposed combining sequences and supplementary-plane characters so tests do not accidentally validate only simple Latin-1 text.

## Sources

- B.C. Digital Code of Practice, [Express cultural and historical awareness and respect](https://digital.gov.bc.ca/design/dcop/cultural-respect/)
- B.C. Government, [Including Indigenous languages in government records, systems and services](https://www2.gov.bc.ca/gov/content/data/initiatives/including-indigenous-languages)
- B.C. Government, [Inclusive Names Service engineering knowledge base](https://github.com/bcgov/inclusive-names-service)
- Unicode Standard Annex #15, [Unicode Normalization Forms](https://unicode.org/reports/tr15/)
- W3C, [Character Model for the World Wide Web: String Matching](https://www.w3.org/TR/charmod-norm/)
