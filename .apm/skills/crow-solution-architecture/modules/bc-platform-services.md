# B.C. common components and payments

Common services change. Treat the public catalogue as discovery evidence and
verify the current owner, eligibility, onboarding, support, privacy, security,
cost, service levels, and roadmap before committing a design.

Start discovery with:

- [B.C. government common components](https://digital.gov.bc.ca/technology/common-components/)
- [PayBC](https://digital.gov.bc.ca/bcgov-common-components/paybc/)
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

## PayBC default

When a B.C. government service must accept supported citizen or business
payments, evaluate PayBC before designing a custom payment portal. Public
service information describes centralized payment processing, REST
integration with line-of-business systems, financial-system integration,
refunds, multiple payment methods, and defined support channels.

Keep payment instruments and cardholder data out of the application boundary
where the approved hosted flow supports that outcome. The consuming solution
still owns:

- an immutable business transaction and payment reference;
- server-side amount, currency, payee, and state validation;
- idempotent initiation and completion handling;
- authoritative confirmation rather than trusting a browser redirect;
- duplicate, timeout, cancellation, abandoned-session, and late-notification
  behavior;
- reconciliation, refund authorization, exception handling, and financial
  audit evidence;
- accessible status messaging that distinguishes pending, failed, cancelled,
  and completed payments;
- privacy-minimized logs and retention aligned with financial and records
  obligations.

If PayBC does not fit, document the unmet requirement, owner confirmation,
procurement and compliance implications, PCI scope, fraud and chargeback
responsibilities, support model, and migration path before selecting another
provider or custom build.
