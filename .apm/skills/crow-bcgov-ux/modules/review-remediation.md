# Existing Application Review and Remediation

## Review scope

Record:

- application and frontend technology;
- routes/screens and states reviewed;
- shared shell, navigation, tokens, and component primitives reviewed;
- browsers, viewport sizes, zoom levels, input methods, and assistive technologies used;
- automated tools and versions;
- exclusions and reasons.

For large applications, select representative screens across:

- navigation and application shell;
- content-heavy pages;
- forms and validation;
- forms or record views containing sensitive identifiers such as SINs;
- search, filters, tables, and pagination;
- dialogs and destructive actions;
- loading, empty, permission-denied, not-found, offline, success, warning, and error states.
- automated eligibility/denial or external-register results, including
  explanation, provenance, recourse, pending, stale, degraded, and assisted
  states when present.

Do not equate a representative sample with full-app conformance.

## Review order

1. Official package/token currency and global font setup.
2. Shared page shell, landmarks, headings, navigation, skip link, title, and responsive behaviour.
3. Shared components and all reachable states.
4. Form semantics, sensitive-value masking and reveal controls, validation, error recovery, and confirmation.
5. Keyboard, focus, announcements, motion, zoom/reflow, and contrast.
6. Screen-specific composition and content.
7. Point-of-use decision explanation, provenance, recourse, and consequential
   service states when the sampled surface has them.

Prioritize shared root causes. A correction to a token, primitive, or shared template is preferable to repeated page-level overrides when regression risk is controlled.

## Finding format

Each finding must include:

```text
Severity: Blocker | High | Medium | Low
Status: Verified | Needs manual verification
Location: repository-relative file and line, selector, or component
Observed: evidence from source and/or interaction
Rule: B.C. Design System source and/or WCAG 2.2 criterion
Impact: affected users and task consequence
Remediation: specific standards-aligned change
Applied: Yes | No | Partial
Verification: test performed and result
```

Severity:

- **Blocker:** prevents a critical task or creates a serious accessibility barrier with no practical workaround.
- **High:** prevents or substantially impairs common operation for a user group, or is a repeated shared defect.
- **Medium:** creates material friction or a conformance failure with a workaround.
- **Low:** localized inconsistency or usability issue with limited task impact.

Do not report a source-only suspicion as verified behaviour. Mark it for manual verification.

## Remediation rules

- Preserve business rules, route outcomes, authorization, data contracts, and approved content unless explicitly asked to change them.
- Fix shared causes before instances, but inspect all usages and run regression tests.
- Replace custom widgets with native controls or released B.C. components when behaviour permits.
- Introduce a centralized token adapter rather than duplicating resolved token values.
- Avoid broad visual rewrites when a focused component/template correction resolves the defect.
- Do not silence accessibility tooling or weaken thresholds to pass a check.
- Capture intentional exceptions with the applicable WCAG exception and evidence.

## Completion report

Summarize:

- scope and sampling limitations;
- finding counts by severity and status;
- files/components changed;
- automated checks and results;
- manual checks and results;
- unresolved findings and ownership;
- known design-system gaps;
- assistive-technology or usability validation still recommended.
