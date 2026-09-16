# B.C. identity, authentication, and authorization

Use current authoritative service documentation and an approved identity
specialist for the final integration. Provider availability, names,
eligibility, and assurance can change.

Start discovery with:

- [B.C. government developer resources](https://developer.gov.bc.ca/)
- [Common Hosted Single Sign-on](https://developer.gov.bc.ca/docs/default/component/css-docs/)
- [BCeID](https://www.bceid.ca/)
- [BC Services Card](https://www2.gov.bc.ca/gov/content/governments/government-id/bc-services-card)

Record the page reviewed, review date, service owner, and unresolved onboarding
or assurance questions in the solution document.

## Select identity by population and assurance

| Population or access path | Preferred starting point | Decision checks |
| :--- | :--- | :--- |
| B.C. public-service workforce | Federation through the approved government single sign-on service using the workforce identity source | Workforce eligibility, MFA and assurance, group freshness, offboarding, privileged administration, and emergency access |
| Businesses and organizations | An approved organizational identity such as Business BCeID when the service must identify an organization or authorized representative | Organization binding, delegation, representative lifecycle, account recovery, and whether the asserted relationship is sufficient for the transaction |
| Individual members of the public | BC Services Card Login when verified personal identity and high assurance are required; BCeID only when its current account types and low or medium assurance fit the transaction | Required identity attributes, assurance, accessibility, alternatives for people unable to use the preferred credential, consent, account recovery, and data minimization |
| Partner or jurisdiction users | Approved federation where governance, claim semantics, assurance, and incident handling are explicit | Trust agreement, issuer and audience, attribute authority, revocation, support, and exit |
| Workloads and service calls | Platform workload identity or OAuth 2.0 client credentials with short-lived, narrowly scoped tokens | Credential custody, audience, rotation, attribution, least privilege, replay resistance, and revocation |

Personal BCeID retired on July 31, 2025. Do not propose it for a new solution.
Do not infer that a login method alone proves residency, age, organizational
authority, professional status, entitlement, or permission for a transaction.
Obtain only claims required for the stated purpose.

## Authentication design

- Prefer OpenID Connect authorization code flow with PKCE for interactive
  clients. Use a backend-for-frontend and secure `HttpOnly` cookies when that
  materially reduces browser token exposure.
- Validate issuer, audience, signature, lifetime, authorized client, and
  required assurance. Never accept identity from untrusted forwarding headers.
- Define sign-out, session expiry, token refresh, account recovery, identity
  linking, duplicate identities, and provider outage behavior.
- Step up assurance for sensitive operations when supported and justified.
  Never silently let a lower-assurance identity perform a higher-assurance
  action.

## Authorization design

- Model permissions as `subject + action + resource + context`; enforce them
  server-side at every protected operation.
- Use identity-provider groups or roles only as inputs to application policy.
  Keep business delegation, case ownership, tenant or organization scope,
  eligibility, and separation of duties in an authoritative policy boundary.
- Deny by default. Validate resource ownership and organization or tenant scope
  on every object access, export, bulk operation, and administrative action.
- Define provisioning, approval, periodic review, expiry, revocation, and
  emergency-access workflows. Avoid permanent broad roles.
- Emit privacy-minimized authorization decision events with actor, action,
  resource reference, outcome, reason code, assurance, and correlation ID.

## Failure and fallback

An unavailable identity or policy dependency does not authorize access.
Choose explicitly among fail closed, preserve an already established
short-lived session, queue a non-sensitive action, or use an approved assisted
service path. Document maximum duration, user messaging, audit evidence,
revocation behavior, and who approved the fallback.
