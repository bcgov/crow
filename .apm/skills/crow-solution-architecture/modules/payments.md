# Payments

Load this module only when the solution accepts, refunds, reconciles, or
reports payments. Verify current service eligibility, onboarding, support,
privacy, security, accessibility, cost, service levels, and roadmap before
committing a design.

Start discovery with:

- [PayBC](https://digital.gov.bc.ca/bcgov-common-components/paybc/)
- [B.C. government common components](https://digital.gov.bc.ca/technology/common-components/)

## PayBC starting point

For supported citizen or business payments, evaluate PayBC before designing a
custom payment portal. Public service information describes centralized
payment processing, REST integration with line-of-business systems,
financial-system integration, refunds, multiple payment methods, and defined
support channels.

Keep payment instruments and cardholder data out of the application boundary
where an approved hosted flow supports that outcome. The consuming solution
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
