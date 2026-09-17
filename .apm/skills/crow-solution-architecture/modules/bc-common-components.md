# B.C. common components

Common services change. Treat the public catalogue as discovery evidence and
verify the current owner, eligibility, onboarding, support, privacy, security,
accessibility, cost, service levels, and roadmap before committing a design.

Start discovery with:

- [B.C. government common components](https://digital.gov.bc.ca/technology/common-components/)
- [B.C. government DevHub](https://developer.gov.bc.ca/)

## Reuse decision

For each required capability:

1. Describe the business capability without naming a product.
2. Search the current common-components catalogue, DevHub, and existing
   ministry capabilities. Record the URL, owner, review date, eligibility, and
   support contact for each viable candidate.
3. Compare functional fit, assurance, data handling, accessibility,
   availability, support, cost, roadmap, integration contract, and exit path.
4. Select reuse, adapt, or build. Name an owner and record evidence freshness.
5. Put an application-owned adapter around external contracts when it improves
   testability, portability, or failure handling without hiding required
   provider semantics.

Absence from one catalogue is not proof that no shared capability exists.
Record the search boundary and mark the result `Unknown` when discovery is
incomplete.
